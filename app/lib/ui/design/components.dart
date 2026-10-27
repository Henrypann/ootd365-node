// Shared components. Rules: no borders on cards, no shadows except the floating action bar,
// selection is shown by ink (a ring, a check, a filled pill), never by a new color.

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

enum OButtonKind { primary, secondary, quiet }

class OButton extends StatelessWidget {
  const OButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = OButtonKind.primary,
    this.icon,
    this.busy = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final OButtonKind kind;
  final IconData? icon;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final (bg, fg) = switch (kind) {
      OButtonKind.primary => (enabled ? OColors.ink : OColors.sandDeep, enabled ? OColors.onInk : OColors.inkMuted),
      OButtonKind.secondary => (OColors.sand, enabled ? OColors.ink : OColors.inkFaint),
      OButtonKind.quiet => (Colors.transparent, enabled ? OColors.inkSoft : OColors.inkFaint),
    };
    final height = kind == OButtonKind.primary ? 52.0 : 44.0;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 1.6, color: fg))
        else if (icon != null)
          Icon(icon, size: 18, color: fg),
        if (busy || icon != null) const SizedBox(width: OSpace.xs),
        Text(label, style: OType.label.copyWith(color: fg, fontSize: 15, letterSpacing: 0.2)),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: AnimatedContainer(
            duration: OMotion.quick,
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: OSpace.lg),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Round 40pt action for headers: back, add, settings.
class OIconButton extends StatelessWidget {
  const OIconButton({super.key, required this.icon, required this.onPressed, required this.tooltip, this.filled = true});

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: filled ? OColors.surface.withValues(alpha: 0.92) : Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(dimension: 40, child: Icon(icon, size: 20, color: OColors.ink)),
          ),
        ),
      );
}

/// Pill choice. Selected is filled ink; unselected is sand.
class OChip extends StatelessWidget {
  const OChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: OMotion.quick,
            curve: OMotion.curve,
            padding: const EdgeInsets.symmetric(horizontal: OSpace.md, vertical: 9),
            decoration: ShapeDecoration(
              color: selected ? OColors.ink : OColors.sand,
              shape: const StadiumBorder(),
            ),
            child: Text(label, style: OType.label.copyWith(color: selected ? OColors.onInk : OColors.inkSoft)),
          ),
        ),
      );
}

/// Text tabs with a small dot under the active one. Used for category filters.
class OTextTabs<T> extends StatelessWidget {
  const OTextTabs({super.key, required this.values, required this.selected, required this.labelOf, required this.onSelected});

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: OSpace.gutter),
        child: Row(
          children: [
            for (final value in values)
              Semantics(
                selected: value == selected,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelected(value);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: OSpace.lg, top: OSpace.xs, bottom: OSpace.xs),
                    child: Column(
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: OMotion.quick,
                          // Replaces the inherited style, so start from it to keep the app font.
                          style: DefaultTextStyle.of(context).style.merge(OType.label).copyWith(
                            fontSize: 15,
                            color: value == selected ? OColors.ink : OColors.inkFaint,
                            fontWeight: value == selected ? FontWeight.w600 : FontWeight.w400,
                          ),
                          child: Text(labelOf(value)),
                        ),
                        const SizedBox(height: 6),
                        AnimatedOpacity(
                          duration: OMotion.quick,
                          opacity: value == selected ? 1 : 0,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(color: OColors.clay, shape: BoxShape.circle),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

/// Overline + optional trailing text, aligned to the gutter.
class OSectionHeader extends StatelessWidget {
  const OSectionHeader(this.title, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.lg, OSpace.gutter, OSpace.sm)});

  final String title;
  final String? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text(title.toUpperCase(), style: OType.overline)),
            if (trailing != null) Text(trailing!, style: OType.caption),
          ],
        ),
      );
}

/// Screen masthead: small overline, large serif title, optional supporting line and actions.
class OMasthead extends StatelessWidget {
  const OMasthead({super.key, required this.overline, required this.title, this.subtitle, this.actions = const [], this.onTitleTap});

  final String overline;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.md, OSpace.sm, OSpace.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(overline.toUpperCase(), style: OType.overline),
                  const SizedBox(height: OSpace.xs),
                  GestureDetector(
                    onTap: onTitleTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(child: Text(title, style: OType.display)),
                        if (onTitleTap != null)
                          const Padding(
                            padding: EdgeInsets.only(left: 6, bottom: 8),
                            child: Icon(CupertinoIcons.chevron_down, size: 14, color: OColors.inkMuted),
                          ),
                      ],
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: OSpace.xs),
                    Text(subtitle!, style: OType.bodyMuted),
                  ],
                ],
              ),
            ),
            ...actions,
          ],
        ),
      );
}

/// Portrait asset with optional caption. Selection insets the image inside an ink ring and shows a check.
class OAssetCard extends StatelessWidget {
  const OAssetCard({
    super.key,
    required this.image,
    this.title,
    this.subtitle,
    this.selected = false,
    this.onTap,
    this.aspectRatio = OAspect.asset,
    this.semanticLabel,
  });

  final Widget image;
  final String? title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final double aspectRatio;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? title,
      selected: selected,
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: aspectRatio,
              child: AnimatedContainer(
                duration: OMotion.standard,
                curve: OMotion.curve,
                padding: EdgeInsets.all(selected ? 4 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ORadius.tile + 2),
                  border: Border.all(color: selected ? OColors.ink : Colors.transparent, width: 1.4),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(selected ? ORadius.tile - 3 : ORadius.tile),
                      child: ColoredBox(color: OColors.sand, child: image),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: AnimatedScale(
                        duration: OMotion.standard,
                        curve: Curves.easeOutBack,
                        scale: selected ? 1 : 0,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(color: OColors.ink, shape: BoxShape.circle),
                          child: const Icon(CupertinoIcons.checkmark, size: 12, color: OColors.onInk),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (title != null) ...[
              const SizedBox(height: OSpace.xs),
              Text(title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OType.label.copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
            ],
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: OType.caption),
            ],
          ],
        ),
      ),
    );
  }
}

/// Stand-in for an item with no photo yet: its color word set as a monogram on sand.
class OMonogram extends StatelessWidget {
  const OMonogram({super.key, required this.text, this.size = 36});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: OColors.sand,
        child: Center(
          child: Text(
            text.trim().isEmpty ? '·' : text.trim().characters.first,
            style: OType.headline.copyWith(fontSize: size, color: OColors.inkFaint),
          ),
        ),
      );
}

/// Quiet inline message. Errors use the soft error tint, never a full red bar.
class ONotice extends StatelessWidget {
  const ONotice({super.key, required this.message, this.actionLabel, this.onAction, this.error = true});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.xs, OSpace.gutter, OSpace.xs),
        padding: const EdgeInsets.fromLTRB(OSpace.md, OSpace.sm, OSpace.xs, OSpace.sm),
        decoration: BoxDecoration(
          color: error ? OColors.errorSoft : OColors.claySoft,
          borderRadius: BorderRadius.circular(ORadius.tile),
        ),
        child: Row(
          children: [
            Expanded(child: Text(message, style: OType.label.copyWith(color: error ? OColors.error : OColors.inkSoft, height: 1.45))),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: OColors.ink),
                child: Text(actionLabel!),
              ),
          ],
        ),
      );
}

/// Empty states speak in a serif italic line plus one plain sentence.
class OEmpty extends StatelessWidget {
  const OEmpty({super.key, required this.line, required this.body, this.action});

  final String line;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: OSpace.xl, vertical: OSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(line, textAlign: TextAlign.center, style: OType.serifItalic.copyWith(fontSize: 26)),
            const SizedBox(height: OSpace.sm),
            Text(body, textAlign: TextAlign.center, style: OType.bodyMuted),
            if (action != null) ...[const SizedBox(height: OSpace.lg), action!],
          ],
        ),
      );
}

class ONavItem {
  const ONavItem({required this.icon, required this.activeIcon, required this.label});

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Bottom navigation: hairline top, thin icons, a clay dot under the current tab.
class ONavBar extends StatelessWidget {
  const ONavBar({super.key, required this.items, required this.index, required this.onSelected});

  final List<ONavItem> items;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: OColors.canvas,
          border: Border(top: BorderSide(color: OColors.line, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (final (i, item) in items.indexed)
                  Expanded(
                    child: Semantics(
                      selected: i == index,
                      button: true,
                      label: item.label,
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () {
                          if (i != index) HapticFeedback.selectionClick();
                          onSelected(i);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(i == index ? item.activeIcon : item.icon,
                                size: 22, color: i == index ? OColors.ink : OColors.inkFaint),
                            const SizedBox(height: 4),
                            Text(item.label,
                                style: OType.caption.copyWith(
                                  fontSize: 11,
                                  color: i == index ? OColors.ink : OColors.inkFaint,
                                  fontWeight: i == index ? FontWeight.w600 : FontWeight.w400,
                                )),
                            const SizedBox(height: 4),
                            AnimatedOpacity(
                              duration: OMotion.quick,
                              opacity: i == index ? 1 : 0,
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(color: OColors.clay, shape: BoxShape.circle),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}
