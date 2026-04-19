#include "CBilineRime.h"

#include "X11/keysym.h"
#include <dlfcn.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "rime_api.h"

static void *g_rime_handle = NULL;
static RimeApi *g_rime_api = NULL;
static char g_last_error[1024] = {0};

static void set_last_error(const char *format, ...) {
    va_list args;
    va_start(args, format);
    vsnprintf(g_last_error, sizeof(g_last_error), format, args);
    va_end(args);
}

static void clear_last_error(void) {
    g_last_error[0] = '\0';
}

static char *duplicate_string(const char *text) {
    if (!text) {
        return NULL;
    }
    size_t length = strlen(text);
    char *copy = malloc(length + 1);
    if (!copy) {
        return NULL;
    }
    memcpy(copy, text, length + 1);
    return copy;
}

static void reset_snapshot(BRimeSnapshot *snapshot) {
    if (!snapshot) {
        return;
    }
    snapshot->isComposing = false;
    snapshot->input = NULL;
    snapshot->schemaID = NULL;
    snapshot->pageSize = 0;
    snapshot->pageNo = 0;
    snapshot->isLastPage = true;
    snapshot->highlightedIndex = 0;
    snapshot->candidateCount = 0;
    snapshot->candidates = NULL;
}

static void copy_snapshot(
    BRimeSessionId sessionID,
    RimeContext *context,
    RimeStatus *status,
    BRimeSnapshot *snapshot
) {
    reset_snapshot(snapshot);

    snapshot->isComposing = status ? status->is_composing : false;
    snapshot->input = duplicate_string(g_rime_api->get_input(sessionID));
    snapshot->schemaID = duplicate_string(status ? status->schema_id : NULL);

    if (!context) {
        return;
    }

    snapshot->pageSize = context->menu.page_size;
    snapshot->pageNo = context->menu.page_no;
    snapshot->isLastPage = context->menu.is_last_page;
    snapshot->highlightedIndex = context->menu.highlighted_candidate_index;
    snapshot->candidateCount = context->menu.num_candidates;

    if (context->menu.num_candidates <= 0 || !context->menu.candidates) {
        return;
    }

    snapshot->candidates = calloc((size_t) context->menu.num_candidates, sizeof(BRimeCandidate));
    if (!snapshot->candidates) {
        set_last_error("Failed to allocate Rime candidate array.");
        snapshot->candidateCount = 0;
        return;
    }

    for (int index = 0; index < context->menu.num_candidates; index++) {
        snapshot->candidates[index].text = duplicate_string(context->menu.candidates[index].text);
        snapshot->candidates[index].comment = duplicate_string(context->menu.candidates[index].comment);
    }
}

bool BRimeSetup(
    const char *libraryPath,
    const char *sharedDataDir,
    const char *userDataDir,
    const char *logDir,
    const char *appName
) {
    clear_last_error();

    if (g_rime_api) {
        return true;
    }

    if (!libraryPath || !sharedDataDir || !userDataDir || !appName) {
        set_last_error("Missing required Rime setup argument.");
        return false;
    }

    g_rime_handle = dlopen(libraryPath, RTLD_NOW | RTLD_LOCAL);
    if (!g_rime_handle) {
        set_last_error("Failed to dlopen librime: %s", dlerror());
        return false;
    }

    RimeApi *(*get_api)(void) = dlsym(g_rime_handle, "rime_get_api");
    if (!get_api) {
        set_last_error("Failed to load rime_get_api: %s", dlerror());
        dlclose(g_rime_handle);
        g_rime_handle = NULL;
        return false;
    }

    g_rime_api = get_api();
    if (!g_rime_api) {
        set_last_error("librime returned a null API handle.");
        dlclose(g_rime_handle);
        g_rime_handle = NULL;
        return false;
    }

    RIME_STRUCT(RimeTraits, traits);
    traits.shared_data_dir = sharedDataDir;
    traits.user_data_dir = userDataDir;
    traits.distribution_name = "BilineIME";
    traits.distribution_code_name = "BilineIME";
    traits.distribution_version = "0.1.0";
    traits.app_name = appName;
    traits.log_dir = logDir;

    g_rime_api->setup(&traits);
    g_rime_api->deployer_initialize(&traits);
    g_rime_api->initialize(&traits);
    return true;
}

void BRimeFinalize(void) {
    if (g_rime_api) {
        g_rime_api->finalize();
        g_rime_api = NULL;
    }
    if (g_rime_handle) {
        dlclose(g_rime_handle);
        g_rime_handle = NULL;
    }
    clear_last_error();
}

bool BRimeDeploy(void) {
    clear_last_error();
    if (!g_rime_api) {
        set_last_error("Rime API is not initialized.");
        return false;
    }
    if (!g_rime_api->deploy()) {
        set_last_error("Rime deploy failed.");
        return false;
    }
    if (RIME_API_AVAILABLE(g_rime_api, is_maintenance_mode) &&
        g_rime_api->is_maintenance_mode() &&
        RIME_API_AVAILABLE(g_rime_api, join_maintenance_thread)) {
        g_rime_api->join_maintenance_thread();
    }
    return true;
}

bool BRimeDeploySchema(const char *schemaFileName) {
    clear_last_error();
    if (!g_rime_api || !schemaFileName) {
        set_last_error("Rime API is not initialized or schema file name is missing.");
        return false;
    }
    if (!g_rime_api->deploy_schema(schemaFileName)) {
        set_last_error("Rime deploy_schema failed for %s.", schemaFileName);
        return false;
    }
    if (RIME_API_AVAILABLE(g_rime_api, is_maintenance_mode) &&
        g_rime_api->is_maintenance_mode() &&
        RIME_API_AVAILABLE(g_rime_api, join_maintenance_thread)) {
        g_rime_api->join_maintenance_thread();
    }
    return true;
}

BRimeSessionId BRimeCreateSession(void) {
    clear_last_error();
    if (!g_rime_api) {
        set_last_error("Rime API is not initialized.");
        return 0;
    }
    RimeSessionId sessionID = g_rime_api->create_session();
    if (!sessionID) {
        set_last_error("Failed to create Rime session.");
    }
    return sessionID;
}

bool BRimeDestroySession(BRimeSessionId sessionID) {
    clear_last_error();
    if (!g_rime_api) {
        set_last_error("Rime API is not initialized.");
        return false;
    }
    return g_rime_api->destroy_session(sessionID);
}

bool BRimeSelectSchema(BRimeSessionId sessionID, const char *schemaID) {
    clear_last_error();
    if (!g_rime_api || !schemaID) {
        set_last_error("Schema selection requires initialized Rime API and schema id.");
        return false;
    }
    if (!g_rime_api->select_schema(sessionID, schemaID)) {
        set_last_error("Failed to select Rime schema: %s", schemaID);
        return false;
    }
    return true;
}

bool BRimeSetOption(BRimeSessionId sessionID, const char *optionName, bool enabled) {
    clear_last_error();
    if (!g_rime_api || !optionName) {
        set_last_error("Rime option change requires initialized API and option name.");
        return false;
    }
    g_rime_api->set_option(sessionID, optionName, enabled ? True : False);
    return true;
}

bool BRimeSetInput(BRimeSessionId sessionID, const char *input) {
    clear_last_error();
    if (!g_rime_api || !input) {
        set_last_error("Rime set_input requires initialized API and input.");
        return false;
    }
    if (!g_rime_api->set_input(sessionID, input)) {
        set_last_error("Rime set_input failed for: %s", input);
        return false;
    }
    return true;
}

bool BRimeSimulateKeySequence(BRimeSessionId sessionID, const char *sequence) {
    clear_last_error();
    if (!g_rime_api || !sequence) {
        set_last_error("Rime simulate_key_sequence requires initialized API and sequence.");
        return false;
    }
    if (!g_rime_api->simulate_key_sequence(sessionID, sequence)) {
        set_last_error("Rime simulate_key_sequence failed for %s", sequence);
        return false;
    }
    return true;
}

bool BRimeProcessKey(BRimeSessionId sessionID, int keycode, int mask) {
    clear_last_error();
    if (!g_rime_api) {
        set_last_error("Rime API is not initialized.");
        return false;
    }
    if (!g_rime_api->process_key(sessionID, keycode, mask)) {
        set_last_error("Rime process_key failed for keycode=%d mask=%d", keycode, mask);
        return false;
    }
    return true;
}

bool BRimeHighlightCandidateOnCurrentPage(BRimeSessionId sessionID, size_t index) {
    clear_last_error();
    if (!g_rime_api) {
        set_last_error("Rime API is not initialized.");
        return false;
    }
    if (!g_rime_api->highlight_candidate_on_current_page(sessionID, index)) {
        set_last_error("Failed to highlight candidate %zu on current page.", index);
        return false;
    }
    return true;
}

bool BRimeSelectCandidateOnCurrentPage(BRimeSessionId sessionID, size_t index, BRimeCommitResult *result) {
    clear_last_error();
    if (!g_rime_api || !result) {
        set_last_error("Rime API is not initialized or commit result is missing.");
        return false;
    }

    result->committedText = NULL;
    reset_snapshot(&result->postCommitSnapshot);

    if (!g_rime_api->select_candidate_on_current_page(sessionID, index)) {
        set_last_error("Failed to select candidate %zu on current page.", index);
        return false;
    }

    RIME_STRUCT(RimeCommit, commit);
    if (g_rime_api->get_commit(sessionID, &commit)) {
        result->committedText = duplicate_string(commit.text);
        g_rime_api->free_commit(&commit);
    }

    if (!BRimeGetSnapshot(sessionID, &result->postCommitSnapshot)) {
        BRimeFreeCommitResult(result);
        return false;
    }

    return true;
}

bool BRimeChangePage(BRimeSessionId sessionID, bool backward) {
    clear_last_error();
    if (!g_rime_api) {
        set_last_error("Rime API is not initialized.");
        return false;
    }
    if (!g_rime_api->change_page(sessionID, backward ? True : False)) {
        set_last_error("Failed to change Rime page.");
        return false;
    }
    return true;
}

bool BRimeGetSnapshot(BRimeSessionId sessionID, BRimeSnapshot *snapshot) {
    clear_last_error();
    if (!g_rime_api || !snapshot) {
        set_last_error("Snapshot requires initialized API and output buffer.");
        return false;
    }

    RIME_STRUCT(RimeContext, context);
    RIME_STRUCT(RimeStatus, status);
    Bool has_context = g_rime_api->get_context(sessionID, &context);
    Bool has_status = g_rime_api->get_status(sessionID, &status);

    copy_snapshot(
        sessionID,
        has_context ? &context : NULL,
        has_status ? &status : NULL,
        snapshot
    );

    if (has_context) {
        g_rime_api->free_context(&context);
    }
    if (has_status) {
        g_rime_api->free_status(&status);
    }
    return true;
}

bool BRimeCommitComposition(BRimeSessionId sessionID, BRimeCommitResult *result) {
    clear_last_error();
    if (!g_rime_api || !result) {
        set_last_error("Commit requires initialized API and output buffer.");
        return false;
    }

    result->committedText = NULL;
    reset_snapshot(&result->postCommitSnapshot);

    if (!g_rime_api->commit_composition(sessionID)) {
        set_last_error("Rime commit_composition returned false.");
        return false;
    }

    RIME_STRUCT(RimeCommit, commit);
    if (!g_rime_api->get_commit(sessionID, &commit)) {
        set_last_error("Rime commit returned no text.");
        return false;
    }

    result->committedText = duplicate_string(commit.text);
    g_rime_api->free_commit(&commit);

    if (!BRimeGetSnapshot(sessionID, &result->postCommitSnapshot)) {
        BRimeFreeCommitResult(result);
        return false;
    }
    return true;
}

char *BRimeCopyLastError(void) {
    if (g_last_error[0] == '\0') {
        return NULL;
    }
    return duplicate_string(g_last_error);
}

void BRimeFreeCString(char *text) {
    free(text);
}

void BRimeFreeSnapshot(BRimeSnapshot *snapshot) {
    if (!snapshot) {
        return;
    }

    free(snapshot->input);
    snapshot->input = NULL;

    free(snapshot->schemaID);
    snapshot->schemaID = NULL;

    if (snapshot->candidates) {
        for (int index = 0; index < snapshot->candidateCount; index++) {
            free(snapshot->candidates[index].text);
            free(snapshot->candidates[index].comment);
        }
        free(snapshot->candidates);
        snapshot->candidates = NULL;
    }

    snapshot->candidateCount = 0;
}

void BRimeFreeCommitResult(BRimeCommitResult *result) {
    if (!result) {
        return;
    }

    free(result->committedText);
    result->committedText = NULL;
    BRimeFreeSnapshot(&result->postCommitSnapshot);
}
