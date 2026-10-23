import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:eal_scanner/services/settingsService.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// What the camera screen came back with.
sealed class ScannerOutcome {
  const ScannerOutcome();
}

/// A code was read.
class ScannerCaptured extends ScannerOutcome {
  const ScannerCaptured(this.capture);
  final BarcodeCapture capture;
}

/// The operator asked to type the serial instead — a torn or smudged label.
class ScannerAskedToType extends ScannerOutcome {
  const ScannerAskedToType();
}

/// The camera, replacing the three copies of `scannerView.dart`.
///
/// Changes that matter on a plant floor: the step being scanned is named at
/// the top, anything already captured stays on screen so it need not be
/// remembered, the torch follows the saved preference, and typing the serial
/// is offered here rather than being impossible.
class ScannerCamera extends StatefulWidget {
  const ScannerCamera({
    super.key,
    required this.stepLabel,
    required this.instruction,
    this.stepIndex,
    this.stepCount,
    this.capturedPrefix,
    this.capturedSerial,
    this.accent = AppColors.blue,
    this.onRedoCaptured,
  });

  /// e.g. "Scan the last label".
  final String stepLabel;

  /// The one-line hint under the reticle.
  final String instruction;

  final int? stepIndex;
  final int? stepCount;

  /// Shown in the confirmation strip, so the first serial stays visible while
  /// the second is being scanned.
  final String? capturedPrefix;
  final int? capturedSerial;

  final Color accent;
  final VoidCallback? onRedoCaptured;

  @override
  State<ScannerCamera> createState() => _ScannerCameraState();
}

class _ScannerCameraState extends State<ScannerCamera> {
  late bool _torchOn = SettingsService.torchByDefault;

  /// The torch is set here rather than toggled once the view is up: a
  /// toggle raced the camera starting, the controller refused it before
  /// the camera was running, and the switch quietly went back to off.
  late final MobileScannerController _controller = MobileScannerController(
    torchEnabled: _torchOn,
  );

  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {
      // Some devices have no torch; leave the state as it was.
    }
  }

  void _handleCapture(BarcodeCapture capture) {
    if (_handled) return;
    if (capture.barcodes.isEmpty) return;

    setState(() => _handled = true);

    if (SettingsService.scanFeedback) {
      // vibrate() and alert carry through where mediumImpact() and the
      // keypress click do not: both of those follow the phone's touch
      // feedback settings, which are off on most of these handsets.
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.alert);
    }

    // A beat on the green frame, so the read is visible before the screen goes.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      Navigator.pop(context, ScannerCaptured(capture));
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasCaptured =
        widget.capturedSerial != null && widget.capturedPrefix != null;

    return Scaffold(
      backgroundColor: AppColors.scannerBase,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _handleCapture),

          // Dim everything outside the reticle so the eye goes to the box.
          const _ReticleOverlay(),
          _Reticle(scanned: _handled),

          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  stepLabel: widget.stepLabel,
                  stepIndex: widget.stepIndex,
                  stepCount: widget.stepCount,
                  onClose: () => Navigator.pop(context),
                ),

                if (hasCaptured)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: _CapturedStrip(
                      prefix: widget.capturedPrefix!,
                      serial: widget.capturedSerial!,
                      onRedo: widget.onRedoCaptured == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              widget.onRedoCaptured!();
                            },
                    ),
                  ),

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _handled ? 'Read' : 'Hold the QR code inside the frame',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: _handled
                              ? AppColors.scannerAccent
                              : AppColors.scannerInk,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.instruction,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: AppColors.scannerMuted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // The torch is the control reached for most often in a
                      // dim store, so it sits in the thumb zone rather than
                      // the far top corner.
                      _TorchPill(on: _torchOn, onPressed: _toggleTorch),
                      const SizedBox(height: 10),
                      // Quiet by design: typing a serial is the fallback, and
                      // a solid button here competed with the scanner itself.
                      SizedBox(
                        height: AppSpace.touch,
                        child: TextButton(
                          onPressed: () => Navigator.pop(
                            context,
                            const ScannerAskedToType(),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.scannerMuted,
                            textStyle: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Label damaged? Type it by hand'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.stepLabel,
    required this.onClose,
    this.stepIndex,
    this.stepCount,
  });

  final String stepLabel;
  final int? stepIndex;
  final int? stepCount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _RoundButton(
            icon: Icons.close_rounded,
            tooltip: 'Close scanner',
            onPressed: onClose,
          ),
          Expanded(
            child: Column(
              children: [
                if (stepIndex != null && stepCount != null)
                  Text(
                    'STEP $stepIndex OF $stepCount',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.92,
                      color: AppColors.scannerMuted,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  stepLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.scannerInk,
                  ),
                ),
              ],
            ),
          ),
          // Balances the close button so the step stays centred.
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// A labelled pill rather than a bare icon: in a dark viewfinder an icon
/// alone gives no clue whether the torch is already on.
class _TorchPill extends StatelessWidget {
  const _TorchPill({required this.on, required this.onPressed});

  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: on,
      label: on ? 'Torch on' : 'Torch off',
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          on ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
          size: 19,
        ),
        label: Text(on ? 'Torch on' : 'Torch off'),
        style: ElevatedButton.styleFrom(
          backgroundColor: on ? AppColors.scannerInk : AppColors.scannerVeil,
          foregroundColor: on ? AppColors.scannerBase : AppColors.scannerInk,
          elevation: 0,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 22),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.scannerVeil,
          foregroundColor: AppColors.scannerInk,
        ),
      ),
    );
  }
}

class _CapturedStrip extends StatelessWidget {
  const _CapturedStrip({
    required this.prefix,
    required this.serial,
    this.onRedo,
  });

  final String prefix;
  final int serial;
  final VoidCallback? onRedo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_rounded,
            size: 18,
            color: AppColors.scannerAccent,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'First label captured',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.scannerMuted,
                  ),
                ),
                const SizedBox(height: 1),
                SerialValue(
                  serial: serial,
                  prefix: prefix,
                  size: 14,
                  color: AppColors.scannerInk,
                  dimColor: const Color(0xFF6E7E96),
                ),
              ],
            ),
          ),
          if (onRedo != null)
            TextButton(
              onPressed: onRedo,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.scannerInk,
                minimumSize: const Size(0, 36),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(9)),
                ),
              ),
              child: const Text('Redo'),
            ),
        ],
      ),
    );
  }
}

/// Four dim panels around a clear window.
class _ReticleOverlay extends StatelessWidget {
  const _ReticleOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = _reticleRect(constraints);
        final dim = Colors.black.withValues(alpha: 0.62);

        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: box.top,
              child: ColoredBox(color: dim),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: box.bottom,
              bottom: 0,
              child: ColoredBox(color: dim),
            ),
            Positioned(
              left: 0,
              width: box.left,
              top: box.top,
              height: box.height,
              child: ColoredBox(color: dim),
            ),
            Positioned(
              right: 0,
              width: constraints.maxWidth - box.right,
              top: box.top,
              height: box.height,
              child: ColoredBox(color: dim),
            ),
          ],
        );
      },
    );
  }
}

class _Reticle extends StatelessWidget {
  const _Reticle({required this.scanned});

  final bool scanned;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = _reticleRect(constraints);
        final color = scanned ? AppColors.scannerAccent : Colors.white;

        return Positioned(
          left: box.left,
          top: box.top,
          width: box.width,
          height: box.height,
          child: IgnorePointer(
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                _Corner(color: color, top: true, left: true),
                _Corner(color: color, top: true, left: false),
                _Corner(color: color, top: false, left: true),
                _Corner(color: color, top: false, left: false),
                Center(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: AppColors.scannerAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.color, required this.top, required this.left});

  final Color color;
  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) {
    const side = 34.0;
    const thickness = 3.5;

    return Positioned(
      top: top ? -2 : null,
      bottom: top ? null : -2,
      left: left ? -2 : null,
      right: left ? null : -2,
      child: SizedBox(
        width: side,
        height: side,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: top
                  ? BorderSide(color: color, width: thickness)
                  : BorderSide.none,
              bottom: top
                  ? BorderSide.none
                  : BorderSide(color: color, width: thickness),
              left: left
                  ? BorderSide(color: color, width: thickness)
                  : BorderSide.none,
              right: left
                  ? BorderSide.none
                  : BorderSide(color: color, width: thickness),
            ),
            borderRadius: BorderRadius.only(
              topLeft: top && left ? const Radius.circular(16) : Radius.zero,
              topRight: top && !left ? const Radius.circular(16) : Radius.zero,
              bottomLeft: !top && left
                  ? const Radius.circular(16)
                  : Radius.zero,
              bottomRight: !top && !left
                  ? const Radius.circular(16)
                  : Radius.zero,
            ),
          ),
        ),
      ),
    );
  }
}

/// A square window. An excise sticker is roughly square, and a square frame
/// is easier to line up one-handed than a letterbox.
Rect _reticleRect(BoxConstraints constraints) {
  final width = constraints.maxWidth - 68;
  final height = width;
  final left = (constraints.maxWidth - width) / 2;
  // Sits above centre so the whole bottom third stays free for controls.
  final top = (constraints.maxHeight - height) / 2 - 30;

  return Rect.fromLTWH(left, top < 0 ? 0 : top, width, height);
}
