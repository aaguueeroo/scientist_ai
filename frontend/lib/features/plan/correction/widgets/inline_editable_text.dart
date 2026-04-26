import 'package:flutter/material.dart' hide Material;
import 'package:flutter/material.dart' as m show Material;
import 'package:flutter/services.dart';

import '../../../../core/theme/theme_context.dart';

class InlineEditableText extends StatefulWidget {
  const InlineEditableText({
    super.key,
    required this.value,
    required this.onSubmitted,
    this.style,
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.minLines,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.placeholderWhenEmpty,
    this.expandHorizontally = false,
  });

  final String value;
  final ValueChanged<String> onSubmitted;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final int? minLines;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? placeholderWhenEmpty;
  final bool expandHorizontally;

  @override
  State<InlineEditableText> createState() => _InlineEditableTextState();
}

class _InlineEditableTextState extends State<InlineEditableText> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = false;
  bool _openEditScheduled = false;
  /// Shown in the label after commit while [widget.value] has not yet caught
  /// up from the parent (commit callback is not synchronous).
  String? _pendingCommittedLabel;
  /// Label (or last pending) the user had when the current edit session started.
  late String _editSessionBaseline;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant InlineEditableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pendingCommittedLabel != null) {
      if (widget.value == _pendingCommittedLabel) {
        _pendingCommittedLabel = null;
      } else if (oldWidget.value != widget.value) {
        _pendingCommittedLabel = null;
      }
    }
    if (!_isEditing && oldWidget.value != widget.value) {
      if (_pendingCommittedLabel == null) {
        _controller.text = widget.value;
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _commit();
    }
  }

  void _enterEditing() {
    if (_isEditing || _openEditScheduled) {
      return;
    }
    _openEditScheduled = true;
    // Defer so setState and focus are not run during the same pointer /
    // mouse-tracker pass as the label tap (avoids
    // !_debugDuringDeviceUpdate on desktop/web).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openEditScheduled = false;
      if (!mounted || _isEditing) {
        return;
      }
      setState(() {
        _editSessionBaseline = _pendingCommittedLabel ?? widget.value;
        _isEditing = true;
        _controller.text = _editSessionBaseline;
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    });
  }

  void _commit() {
    final String next = _controller.text;
    if (next != widget.value) {
      setState(() {
        _isEditing = false;
        _pendingCommittedLabel = next;
      });
      final String submitted = next;
      // Not synchronous with focus/pointer, but before next frame; avoids
      // mouse-tracker re-entrance. Optimistic [ _pendingCommittedLabel ] keeps
      // the label correct until the parent rebuilds.
      Future.microtask(() {
        if (mounted) {
          widget.onSubmitted(submitted);
        }
      });
    } else {
      setState(() => _isEditing = false);
    }
  }

  void _cancel() {
    setState(() {
      _isEditing = false;
      _controller.text = _editSessionBaseline;
      if (_editSessionBaseline == widget.value) {
        _pendingCommittedLabel = null;
      } else {
        _pendingCommittedLabel = _editSessionBaseline;
      }
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return _buildEditor(context);
    }
    return _buildLabel(context);
  }

  Widget _buildLabel(BuildContext context) {
    final TextStyle effectiveStyle =
        widget.style ?? Theme.of(context).textTheme.bodyMedium!;
    final String valueForLabel = _pendingCommittedLabel ?? widget.value;
    final bool isEmpty = valueForLabel.trim().isEmpty;
    final String shown = isEmpty
        ? (widget.placeholderWhenEmpty ?? widget.hintText ?? '')
        : valueForLabel;
    final TextStyle shownStyle = isEmpty
        ? effectiveStyle.copyWith(color: context.scientist.onSurfaceFaint)
        : effectiveStyle;
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _enterEditing,
        child: Text(
          shown,
          style: shownStyle,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          softWrap: widget.maxLines != 1,
          overflow:
              widget.maxLines == null ? null : TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final TextStyle effectiveStyle =
        widget.style ?? Theme.of(context).textTheme.bodyMedium!;
    final Widget editor = Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): _CancelIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CancelIntent: CallbackAction<_CancelIntent>(
            onInvoke: (_CancelIntent intent) {
              _cancel();
              return null;
            },
          ),
        },
        child: m.Material(
          color: Colors.transparent,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            style: effectiveStyle,
            textAlign: widget.textAlign,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            cursorColor: Theme.of(context).colorScheme.primary,
            decoration: InputDecoration.collapsed(
              hintText: widget.hintText,
              hintStyle: effectiveStyle.copyWith(
                color: context.scientist.onSurfaceFaint,
              ),
            ),
            onSubmitted: (_) => _commit(),
          ),
        ),
      ),
    );
    if (widget.expandHorizontally) {
      return editor;
    }
    return IntrinsicWidth(child: editor);
  }
}

class _CancelIntent extends Intent {
  const _CancelIntent();
}
