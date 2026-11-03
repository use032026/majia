/// The capability set compiled into this plugin branch.
///
/// Hosts must select this value at dependency-resolution time rather than
/// infer it from a bridge callback or a page URL. This is intentionally the
/// only branch-specific Dart source for the runtime mode.
enum StminiRuntimeMode { mini, web }

const configuredStminiRuntimeMode = StminiRuntimeMode.web;
