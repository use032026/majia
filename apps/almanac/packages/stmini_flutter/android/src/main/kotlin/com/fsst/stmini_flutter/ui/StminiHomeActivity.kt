package com.fsst.stmini_flutter.ui

/**
 * Verified `ishome=1` roots live in the embedding application's Task.
 *
 * This deliberately has a separate manifest entry from the document-mode
 * container. Android task/document attributes are manifest-time policy, so
 * they cannot safely be toggled after a package has been opened.
 */
class StminiHomeActivity : StminiContainerActivity()
