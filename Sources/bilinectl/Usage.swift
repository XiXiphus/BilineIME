import Foundation

extension BilineCtl {
    static let usage = """
        usage:
          bilinectl diagnose dev
          bilinectl plan install dev --scope user|system|all [--home <path>]
          bilinectl plan remove dev --scope user|system|all --data preserve|purge [--home <path>]
          bilinectl plan reset dev --scope user|system|all --depth refresh|cache-prune|launch-services-reset [--home <path>]
          bilinectl plan prepare-release dev --scope user|system|all [--home <path>]
          bilinectl install dev --scope user|system|all --confirm [--home <path>]
          bilinectl remove dev --scope user|system|all --data preserve|purge --confirm [--home <path>]
          bilinectl reset dev --scope user|system|all --depth refresh|cache-prune|launch-services-reset --confirm [--home <path>]
          bilinectl prepare-release dev --scope user|system|all --confirm [--home <path>]
          bilinectl credentials status|configure|clear dev
          bilinectl smoke-host dev --check [--home <path>]
          bilinectl smoke-host dev --prepare [--home <path>]
          bilinectl smoke-host dev [--scenario candidate-popup|browse|commit|settings-refresh|full] --confirm [--home <path>]
        """
}
