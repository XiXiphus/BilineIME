#ifndef CBILINERIME_H
#define CBILINERIME_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef uintptr_t BRimeSessionId;

typedef struct {
    char *text;
    char *comment;
} BRimeCandidate;

typedef struct {
    bool isComposing;
    char *input;
    char *schemaID;
    int pageSize;
    int pageNo;
    bool isLastPage;
    int highlightedIndex;
    int candidateCount;
    BRimeCandidate *candidates;
} BRimeSnapshot;

typedef struct {
    char *committedText;
    BRimeSnapshot postCommitSnapshot;
} BRimeCommitResult;

bool BRimeSetup(
    const char *libraryPath,
    const char *sharedDataDir,
    const char *userDataDir,
    const char *logDir,
    const char *appName
);
void BRimeFinalize(void);
bool BRimeDeploy(void);
bool BRimeDeploySchema(const char *schemaFileName);
BRimeSessionId BRimeCreateSession(void);
bool BRimeDestroySession(BRimeSessionId sessionID);
bool BRimeSelectSchema(BRimeSessionId sessionID, const char *schemaID);
bool BRimeSetOption(BRimeSessionId sessionID, const char *optionName, bool enabled);
bool BRimeSetInput(BRimeSessionId sessionID, const char *input);
bool BRimeProcessKey(BRimeSessionId sessionID, int keycode, int mask);
bool BRimeSimulateKeySequence(BRimeSessionId sessionID, const char *sequence);
bool BRimeHighlightCandidateOnCurrentPage(BRimeSessionId sessionID, size_t index);
bool BRimeSelectCandidateOnCurrentPage(BRimeSessionId sessionID, size_t index, BRimeCommitResult *result);
bool BRimeChangePage(BRimeSessionId sessionID, bool backward);
bool BRimeGetSnapshot(BRimeSessionId sessionID, BRimeSnapshot *snapshot);
bool BRimeCommitComposition(BRimeSessionId sessionID, BRimeCommitResult *result);
char *BRimeCopyLastError(void);
void BRimeFreeCString(char *text);
void BRimeFreeSnapshot(BRimeSnapshot *snapshot);
void BRimeFreeCommitResult(BRimeCommitResult *result);

#endif
