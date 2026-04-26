import 'package:flutter/material.dart' hide Material;
import 'package:flutter/material.dart' as m show Material;
import 'package:flutter/services.dart';

import '../../../../core/theme/theme_context.dart';
import 'edit_highlight.dart';

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
    this.onLiveChanged,
  });

  final String value;
  final ValueChanged<String> onSubmitted;
  /// Fires on every keystroke while the field is in edit mode. Use to keep
  /// the draft in sync for immediate section highlights. [onSubmitted] is
  /// still called on blur. Callers should also invoke this with the
  /// [value] on cancel to revert the draft.
  final ValueChanged<String>? onLiveChanged;
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
  /// [widget.value] when the user last opened the editor; used to undo on cancel.
  late String _editSessionBaseline;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _editSessionBaseline = widget.value;
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant InlineEditableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.value != widget.value) {
      // Parent (e.g. [PlanReviewController] draft) updated this field.
      _controller.text = widget.value;
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
    if (_isEditing) {
      return;
    }
    setState(() {
      // Label display uses [_controller] when not editing, so the buffer is
      // the visible string at tap time (and matches [widget.value] when in sync).
      _editSessionBaseline = _controller.text;
      _isEditing = true;
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
  }

  void _commit() {
    final String next = _controller.text;
    if (next != widget.value) {
      // [next] is already in [_controller]. Leave editing mode: the label uses
      // [_controller], so the new text is visible before [onSubmitted] runs
      // (e.g. deferred to avoid pointer/mouse-reentrancy) and the parent
      // rebuilds with a new [widget.value].
      setState(() {
        _isEditing = false;
      });
      final String submitted = next;
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
    });
    widget.onLiveChanged?.call(_editSessionBaseline);
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
    // Use the controller, not [widget.value], so commits show immediately
    // even when [onSubmitted] and the parent are handled asynchronously.
    final String valueForLabel = _controller.text;
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
    final TextStyle baseStyle =
        widget.style ?? Theme.of(context).textTheme.bodyMedium!;
    final TextStyle effectiveStyle =
        editingTextHighlight(baseStyle) ?? baseStyle;
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
              hintStyle: baseStyle.copyWith(
                color: context.scientist.onSurfaceFaint,
                backgroundColor: Colors.transparent,
              ),
            ),
            onChanged: (String s) {
              widget.onLiveChanged?.call(s);
            },
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
