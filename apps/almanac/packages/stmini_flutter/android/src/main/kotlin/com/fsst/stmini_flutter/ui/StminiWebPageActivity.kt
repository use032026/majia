package com.fsst.stmini_flutter.ui

/**
 * A package-owned pushed page.  Unlike [StminiContainerActivity], this
 * Activity deliberately has no document launch mode, so Android appends it
 * to the root Mini Task and system back performs a normal pop.
 */
class StminiWebPageActivity : StminiContainerActivity()
