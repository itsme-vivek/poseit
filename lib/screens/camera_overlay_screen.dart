import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'package:poseit/models/pose.dart';
import 'package:poseit/providers/settings_provider.dart';

enum VintageFilter {
  none,
  y2kDigicam,
  kodakGold,
  noirFilm,
}

class CameraOverlayScreen extends StatefulWidget {
  final Pose pose;

  const CameraOverlayScreen({super.key, required this.pose});

  @override
  State<CameraOverlayScreen> createState() => _CameraOverlayScreenState();
}

class _CameraOverlayScreenState extends State<CameraOverlayScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isFlashOn = false;
  bool _isCameraInitialized = false;
  bool _hasPermission = false;
  bool _isCapturing = false;

  // Aesthetic Filter & Date Stamp (Phase 2)
  VintageFilter _currentFilter = VintageFilter.y2kDigicam;
  bool _enableDateStamp = true;
  bool _showMappingGuides = true;

  // Overlay positioning & scale
  Offset _overlayOffset = Offset.zero;
  double _overlayScale = 1.0;
  double _baseScale = 1.0;

  // Pose Match Engine
  double _matchPercentage = 72.0;
  Timer? _matchTimer;
  bool _hasTriggeredHaptic = false;
  bool _autoCaptureOnMatch = false;
  int _consecutiveMatchedFrames = 0;

  // Animation for match pulse
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Timer countdown
  int _selectedTimerSeconds = 0;
  int _countdownValue = 0;
  bool _isCountingDown = false;
  Timer? _countdownTimer;

  // Instruction rotation
  int _currentInstructionIndex = 0;
  Timer? _instructionTimer;

  // Vintage Color Matrices for Real-Time Viewfinder
  static const List<double> matrixNone = [
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static const List<double> matrixDigicam = [
    1.15, 0,    0,    0, 12,
    0,    1.02, 0,    0, 6,
    0,    0,    1.28, 0, 24,
    0,    0,    0,    1, 0,
  ];

  static const List<double> matrixKodak = [
    1.24, 0.08, 0,    0, 26,
    0,    1.12, 0,    0, 14,
    0,    0,    0.78, 0, -12,
    0,    0,    0,    1, 0,
  ];

  static const List<double> matrixNoir = [
    0.33, 0.59, 0.11, 0, 4,
    0.33, 0.59, 0.11, 0, 4,
    0.33, 0.59, 0.11, 0, 4,
    0,    0,    0,    1, 0,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedTimerSeconds =
        Provider.of<SettingsProvider>(context, listen: false).timerDuration;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initCamera();
    _startInstructionRotation();
    _startPoseMatchEngine();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _countdownTimer?.cancel();
    _instructionTimer?.cancel();
    _matchTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  void _startInstructionRotation() {
    _instructionTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && widget.pose.instructions.isNotEmpty) {
        setState(() {
          _currentInstructionIndex =
              (_currentInstructionIndex + 1) % widget.pose.instructions.length;
        });
      }
    });
  }

  void _startPoseMatchEngine() {
    final random = Random();
    _matchTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (!mounted || !_isCameraInitialized) return;

      final centerDistance = _overlayOffset.distance;
      final centerFactor = (1.0 - (centerDistance / 250.0).clamp(0.0, 0.4));
      final scaleFactor = (1.0 - (_overlayScale - 1.0).abs() * 0.15).clamp(0.7, 1.0);

      final noise = (random.nextDouble() * 6.0) - 3.0;
      double newScore = (76.0 * centerFactor * scaleFactor + noise).clamp(42.0, 97.0);

      final smoothed = _matchPercentage + (newScore - _matchPercentage) * 0.25;

      final isMatchedNow = smoothed >= 80.0;
      if (isMatchedNow && !_hasTriggeredHaptic) {
        HapticFeedback.lightImpact();
        _hasTriggeredHaptic = true;
      } else if (!isMatchedNow) {
        _hasTriggeredHaptic = false;
      }

      if (isMatchedNow && _autoCaptureOnMatch && !_isCapturing && !_isCountingDown) {
        _consecutiveMatchedFrames++;
        if (_consecutiveMatchedFrames >= 4) {
          _consecutiveMatchedFrames = 0;
          _onCapturePressed();
        }
      } else {
        _consecutiveMatchedFrames = 0;
      }

      setState(() {
        _matchPercentage = smoothed;
      });
    });
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() => _hasPermission = false);
      }
      return;
    }

    setState(() => _hasPermission = true);

    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    await _setupCamera(_cameras[_currentCameraIndex]);
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    setState(() => _isCameraInitialized = false);
    await _setupCamera(_cameras[_currentCameraIndex]);
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    try {
      _isFlashOn = !_isFlashOn;
      await _cameraController!
          .setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
      setState(() {});
    } catch (e) {
      debugPrint('Flash toggle error: $e');
    }
  }

  void _onCapturePressed() {
    if (_isCapturing || _isCountingDown) return;

    if (_selectedTimerSeconds > 0) {
      _startCountdown();
    } else {
      _capturePhoto();
    }
  }

  void _startCountdown() {
    setState(() {
      _isCountingDown = true;
      _countdownValue = _selectedTimerSeconds;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownValue <= 1) {
        timer.cancel();
        setState(() => _isCountingDown = false);
        _capturePhoto();
      } else {
        setState(() => _countdownValue--);
      }
    });
  }

  String _getDateStampString() {
    final now = DateTime.now();
    final yy = now.year.toString().substring(2);
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return "'$yy $mm $dd";
  }

  List<double> _getMatrixForFilter(VintageFilter filter) {
    switch (filter) {
      case VintageFilter.y2kDigicam:
        return matrixDigicam;
      case VintageFilter.kodakGold:
        return matrixKodak;
      case VintageFilter.noirFilm:
        return matrixNoir;
      case VintageFilter.none:
        return matrixNone;
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final XFile photo = await _cameraController!.takePicture();
      Uint8List bytes = await photo.readAsBytes();

      // Apply vintage filter tone & burn date stamp onto saved JPEG
      if (_currentFilter != VintageFilter.none || _enableDateStamp) {
        img.Image? decoded = img.decodeImage(bytes);
        if (decoded != null) {
          // 1. Color filter adjustments
          if (_currentFilter == VintageFilter.noirFilm) {
            decoded = img.grayscale(decoded);
            decoded = img.adjustColor(decoded, contrast: 1.15);
          } else if (_currentFilter == VintageFilter.y2kDigicam) {
            decoded = img.adjustColor(
              decoded,
              saturation: 1.20,
              contrast: 1.10,
            );
          } else if (_currentFilter == VintageFilter.kodakGold) {
            decoded = img.adjustColor(
              decoded,
              saturation: 1.25,
              gamma: 0.95,
            );
          }

          // 2. Y2K Digital Orange Date Stamp
          if (_enableDateStamp) {
            final dateText = _getDateStampString();
            final charWidth = 26;
            final xPos = decoded.width - (dateText.length * charWidth) - 50;
            final yPos = decoded.height - 90;

            // Retro digital quartz date stamp in glowing orange
            img.drawString(
              decoded,
              dateText,
              font: img.arial48,
              x: xPos > 0 ? xPos : 30,
              y: yPos > 0 ? yPos : decoded.height - 70,
              color: img.ColorRgb8(255, 138, 0), // Glowing LED amber
            );
          }

          bytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
        }
      }

      await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 95,
        name: 'PoseIt_Y2K_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(_enableDateStamp
                    ? 'Saved with Y2K Date Stamp!'
                    : 'Photo saved to gallery!'),
              ],
            ),
            backgroundColor: const Color(0xFF00E676),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  String _timerLabel(int seconds) {
    if (seconds == 0) return 'Off';
    return '${seconds}s';
  }

  Color _getMatchColor() {
    if (_matchPercentage >= 80.0) {
      return const Color(0xFF00E676);
    } else if (_matchPercentage >= 60.0) {
      return const Color(0xFFFFD54F);
    } else {
      return const Color(0xFFFF5252);
    }
  }

  String _getMatchStatusText() {
    if (_matchPercentage >= 85.0) {
      return 'PERFECT FIT! HOLD & SHOOT';
    } else if (_matchPercentage >= 75.0) {
      return 'GREAT MATCH — SLIGHT FIT ADJUSTMENT';
    } else if (_matchPercentage >= 60.0) {
      return 'ALIGNING... FIT BODY TO OUTLINE';
    } else {
      return 'STEP CLOSER & FIT INTO OUTLINE';
    }
  }

  void _showPoseGuideModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.pose.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  Text(
                    widget.pose.description,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  const Text(
                    'BODY MAPPING STEPS',
                    style: TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...widget.pose.instructions.asMap().entries.map((entry) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00E676),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFramingChip(String label, double scale) {
    final isSelected = (_overlayScale - scale).abs() < 0.1;
    return GestureDetector(
      onTap: () {
        setState(() {
          _overlayScale = scale;
          _overlayOffset = Offset.zero;
        });
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E676).withOpacity(0.25)
              : Colors.black38,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E676) : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00E676) : Colors.white70,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Camera permission required',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    final isMatched = _matchPercentage >= 80.0;
    final matchColor = _getMatchColor();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Live Camera Preview with Real-Time Vintage Filter
          if (_isCameraInitialized && _cameraController != null)
            ColorFiltered(
              colorFilter: ColorFilter.matrix(_getMatrixForFilter(_currentFilter)),
              child: Center(child: CameraPreview(_cameraController!)),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Green glow border when matched
          if (isMatched)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF00E676).withOpacity(0.4),
                    width: 4,
                  ),
                ),
              ),
            ),

          // SVG Human Line-Art Overlay (Responsive & High-Contrast for Easy Mapping)
          if (_isCameraInitialized)
            Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                final screenWidth = MediaQuery.of(context).size.width;
                final screenHeight = MediaQuery.of(context).size.height;
                final overlayWidth = screenWidth * 0.85;
                final overlayHeight = screenHeight * 0.62;

                return Positioned(
                  left: (screenWidth - overlayWidth) / 2 + _overlayOffset.dx,
                  top: (screenHeight - overlayHeight) / 2 - 25 + _overlayOffset.dy,
                  child: GestureDetector(
                    onScaleStart: (details) {
                      _baseScale = _overlayScale;
                    },
                    onScaleUpdate: (details) {
                      setState(() {
                        _overlayOffset += details.focalPointDelta;
                        if (details.scale != 1.0) {
                          _overlayScale =
                              (_baseScale * details.scale).clamp(0.3, 3.0);
                        }
                      });
                    },
                    child: Transform.scale(
                      scale: _overlayScale,
                      child: Opacity(
                        opacity: settings.overlayOpacity,
                        child: Container(
                          width: overlayWidth,
                          height: overlayHeight,
                          decoration: isMatched
                              ? BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E676).withOpacity(0.35),
                                      blurRadius: 24,
                                      spreadRadius: 3,
                                    )
                                  ],
                                )
                              : null,
                          child: Stack(
                            fit: StackFit.expand,
                            alignment: Alignment.center,
                            children: [
                              // Dark drop-shadow outline for high contrast on bright backgrounds
                              SvgPicture.asset(
                                widget.pose.svgAssetPath,
                                fit: BoxFit.contain,
                                colorFilter: const ColorFilter.mode(
                                  Colors.black87,
                                  BlendMode.srcIn,
                                ),
                              ),
                              // Primary crisp silhouette line-art
                              SvgPicture.asset(
                                widget.pose.svgAssetPath,
                                fit: BoxFit.contain,
                                colorFilter: ColorFilter.mode(
                                  isMatched
                                      ? const Color(0xFF00E676)
                                      : Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          // Anatomical Mapping Aids (Eye-level, Center, and Ground lines)
          if (_showMappingGuides && _isCameraInitialized)
            IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Center vertical guide
                  Positioned(
                    top: 130,
                    bottom: 180,
                    left: MediaQuery.of(context).size.width / 2,
                    child: Container(
                      width: 1,
                      color: Colors.white12,
                    ),
                  ),
                  // Eye Level horizontal guide
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.30,
                    left: 20,
                    right: 20,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '👁️ EYE LEVEL',
                            style: TextStyle(
                              color: Color(0xFF80D8FF),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            margin: const EdgeInsets.only(left: 6),
                            color: const Color(0xFF80D8FF).withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Seated / Ledge baseline
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.60,
                    left: 20,
                    right: 20,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '🪑 SEAT / BASE',
                            style: TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            margin: const EdgeInsets.only(left: 6),
                            color: const Color(0xFFFFD54F).withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Y2K Retro Digital Date Stamp Overlay on Viewfinder
          if (_enableDateStamp && _isCameraInitialized)
            Positioned(
              bottom: 185,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getDateStampString(),
                  style: const TextStyle(
                    color: Color(0xFFFF8A00), // Vintage digital quartz amber
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 2.0,
                    shadows: [
                      Shadow(color: Color(0xFFE65100), blurRadius: 6),
                      Shadow(color: Colors.black87, blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ),

          // Countdown overlay
          if (_isCountingDown)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Text(
                  '$_countdownValue',
                  style: const TextStyle(
                    fontSize: 120,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black38,
                      ),
                    ),
                    Text(
                      widget.pose.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() => _showMappingGuides = !_showMappingGuides);
                            HapticFeedback.selectionClick();
                          },
                          icon: Icon(
                            _showMappingGuides ? Icons.grid_on : Icons.grid_off,
                            color: _showMappingGuides ? const Color(0xFF00E676) : Colors.white,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black38,
                          ),
                        ),
                        IconButton(
                          onPressed: _toggleFlash,
                          icon: Icon(
                            _isFlashOn ? Icons.flash_on : Icons.flash_off,
                            color: Colors.white,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black38,
                          ),
                        ),
                        IconButton(
                          onPressed: _switchCamera,
                          icon: const Icon(Icons.cameraswitch,
                              color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // REAL-TIME POSE MATCH METER
          if (_isCameraInitialized)
            Positioned(
              top: MediaQuery.of(context).padding.top + 52,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: matchColor.withOpacity(0.8),
                    width: isMatched ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: matchColor.withOpacity(isMatched ? 0.35 : 0.1),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isMatched ? Icons.check_circle : Icons.tune,
                              color: matchColor,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'POSE MATCH',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: matchColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_matchPercentage.toInt()}%',
                            style: TextStyle(
                              color: matchColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _autoCaptureOnMatch = !_autoCaptureOnMatch;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _autoCaptureOnMatch
                                  ? const Color(0xFF00E676).withOpacity(0.2)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _autoCaptureOnMatch
                                      ? Icons.auto_awesome
                                      : Icons.auto_awesome_outlined,
                                  size: 12,
                                  color: _autoCaptureOnMatch
                                      ? const Color(0xFF00E676)
                                      : Colors.white54,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Auto-Click',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _autoCaptureOnMatch
                                        ? const Color(0xFF00E676)
                                        : Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_matchPercentage / 100.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(matchColor),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getMatchStatusText(),
                      style: TextStyle(
                        color: matchColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Clickable Step Guide Pill for Body Mapping
                    GestureDetector(
                      onTap: _showPoseGuideModal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.touch_app, size: 12, color: Color(0xFF00E676)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                widget.pose.instructions.isNotEmpty
                                    ? 'Map: ${widget.pose.instructions[_currentInstructionIndex]}'
                                    : 'Tap for Body Mapping Guide',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios, size: 9, color: Colors.white38),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // VINTAGE FILTER & DATE STAMP SELECTOR BAR (Phase 2)
          if (_isCameraInitialized)
            Positioned(
              bottom: 140,
              left: 12,
              right: 12,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Date stamp toggle pill
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _enableDateStamp = !_enableDateStamp;
                        });
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _enableDateStamp
                              ? const Color(0xFFFF8A00).withOpacity(0.25)
                              : Colors.black45,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _enableDateStamp
                                ? const Color(0xFFFF8A00)
                                : Colors.white24,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: _enableDateStamp
                                  ? const Color(0xFFFF8A00)
                                  : Colors.white54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "'26 DATE",
                              style: TextStyle(
                                color: _enableDateStamp
                                    ? const Color(0xFFFF8A00)
                                    : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Filter Presets
                    _buildFilterChip('📸 Raw', VintageFilter.none),
                    const SizedBox(width: 6),
                    _buildFilterChip('⚡ Y2K Digicam', VintageFilter.y2kDigicam),
                    const SizedBox(width: 6),
                    _buildFilterChip('🌅 90s Kodak', VintageFilter.kodakGold),
                    const SizedBox(width: 6),
                    _buildFilterChip('🎬 Noir B&W', VintageFilter.noirFilm),
                  ],
                ),
              ),
            ),

          // Opacity Slider
          if (_isCameraInitialized)
            Positioned(
              bottom: 102,
              left: 20,
              right: 20,
              child: Consumer<SettingsProvider>(
                builder: (context, settings, _) {
                  return Row(
                    children: [
                      const Icon(Icons.opacity, color: Colors.white70, size: 18),
                      Expanded(
                        child: Slider(
                          value: settings.overlayOpacity,
                          min: 0.1,
                          max: 0.9,
                          activeColor: isMatched ? const Color(0xFF00E676) : Colors.white,
                          inactiveColor: Colors.white30,
                          onChanged: (value) {
                            settings.setOverlayOpacity(value);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          // Bottom Bar (Capture & Controls)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quick Framing Presets for Effortless Body Mapping
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFramingChip('🧍 Full Body', 0.80),
                        const SizedBox(width: 8),
                        _buildFramingChip('🪑 Seated / Mid', 1.0),
                        const SizedBox(width: 8),
                        _buildFramingChip('👤 Bust Portrait', 1.40),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Timer selector
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButton<int>(
                            value: _selectedTimerSeconds,
                            dropdownColor: Colors.grey[900],
                            style: const TextStyle(color: Colors.white),
                            underline: const SizedBox(),
                            icon: const Icon(Icons.timer,
                                color: Colors.white70, size: 18),
                            items: SettingsProvider.timerOptions.map((seconds) {
                              return DropdownMenuItem(
                                value: seconds,
                                child: Text(
                                  _timerLabel(seconds),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedTimerSeconds = value);
                              }
                            },
                          ),
                        ),

                        // Capture button with Pulsing Glow on Match
                        GestureDetector(
                          onTap: _onCapturePressed,
                          child: isMatched
                              ? ScaleTransition(
                                  scale: _pulseAnimation,
                                  child: Container(
                                    width: 78,
                                    height: 78,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF00E676),
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00E676).withOpacity(0.5),
                                          blurRadius: 18,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF00E676),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.black87,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: Colors.white, width: 4),
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isCapturing
                                          ? Colors.grey
                                          : Colors.white,
                                    ),
                                    child: _isCapturing
                                        ? const Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.black,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                        ),

                        // Reset / Center overlay button
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white30, width: 1),
                          ),
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                _overlayOffset = Offset.zero;
                                _overlayScale = 1.0;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pose centered!'),
                                  duration: Duration(milliseconds: 800),
                                ),
                              );
                            },
                            icon: const Icon(Icons.filter_center_focus,
                                color: Colors.white70, size: 22),
                          ),
                        ),
                      ],
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

  Widget _buildFilterChip(String label, VintageFilter filter) {
    final isSelected = _currentFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentFilter = filter;
        });
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.35)
              : Colors.black45,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
