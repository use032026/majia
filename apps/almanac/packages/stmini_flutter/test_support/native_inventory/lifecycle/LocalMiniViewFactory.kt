package com.fsst.stmini_flutter.ui

import io.flutter.plugin.common.BinaryMessenger

/** Inventory lifecycle glue only; never creates a renderer or FlutterEngine. */
class LocalMiniViewFactory(messenger: BinaryMessenger, allowed: () -> Boolean) {
    fun detach() {}
}
