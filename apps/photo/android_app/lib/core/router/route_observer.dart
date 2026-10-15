import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void dismissCurrentKeyboardFocus({Offset? pointerGlobalPosition}) {
  final focus = FocusManager.instance.primaryFocus;
  if (focus == null) return;
  if (pointerGlobalPosition != null &&
      _isPointerInsideFocusedEditable(focus, pointerGlobalPosition)) {
    return;
  }
  focus.unfocus();
  _applyFocusChangesSafely();
}

void _applyFocusChangesSafely() {
  if (SchedulerBinding.instance.schedulerPhase ==
      SchedulerPhase.persistentCallbacks) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.applyFocusChangesIfNeeded();
    });
    return;
  }
  FocusManager.instance.applyFocusChangesIfNeeded();
}

bool _isPointerInsideFocusedEditable(FocusNode focus, Offset globalPosition) {
  final context = focus.context;
  if (context == null) return false;

  final editableState = context.findAncestorStateOfType<EditableTextState>();
  if (editableState != null &&
      _renderObjectContainsGlobalPosition(
        editableState.context.findRenderObject(),
        globalPosition,
      )) {
    return true;
  }

  return _renderObjectContainsGlobalPosition(
    context.findRenderObject(),
    globalPosition,
  );
}

bool _renderObjectContainsGlobalPosition(
  RenderObject? renderObject,
  Offset globalPosition,
) {
  if (renderObject is! RenderBox || !renderObject.attached) return false;
  final local = renderObject.globalToLocal(globalPosition);
  return renderObject.size.contains(local);
}

class STRouteObserver extends RouteObserver<ModalRoute<void>> {
  void _dismissKeyboard() => dismissCurrentKeyboardFocus();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissKeyboard();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissKeyboard();
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _dismissKeyboard();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissKeyboard();
    super.didRemove(route, previousRoute);
  }
}

/// 全局 RouteObserver（用于 RouteAware 生命周期感知）。
///
/// 对齐 iOS 页面 `viewWillAppear` / `viewWillDisappear`：Flutter 页面从子页
/// 返回时通过 `didPopNext` 触发业务刷新。
final STRouteObserver routeObserver = STRouteObserver();
