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
import 'package:poseit/providers/pose_provider.dart';

enum VintageFilter {
  none,
  y2kDigicam,
  kodakGold,
  noirFilm,
}

class CameraOverlayScreen extends StatefulWidget {
  final Pose? pose;
  final List<Pose>? initialPoseList;

  const CameraOverlayScreen({
    super.key,
    this.pose,
    this.initialPoseList,
  });

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

  // Active Pose & SOVS-style In-Camera Carousel
  Pose? _currentPose;
  List<Pose> _carouselPoses = [];
  PoseCategory? _activeCategory;
  final ScrollController _poseCarouselController = ScrollController();
  bool _initializedPoses = false;

  // Silhouette Controls (SOVS layout)
  bool _isSilhouetteFlipped = false;
  bool _showSilhouetteSlider = false;
  double _silhouetteOpacity = 0.70;
  bool _showCategoryPicker = false;

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

    if (widget.pose != null) {
      _currentPose = widget.pose!;
      _activeCategory = _currentPose!.category;
    }

    _initCamera();
    _startInstructionRotation();
    _startPoseMatchEngine();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedPoses) {
      final poseProvider = Provider.of<PoseProvider>(context, listen: false);
      if (widget.initialPoseList != null && widget.initialPoseList!.isNotEmpty) {
        _carouselPoses = List<Pose>.from(widget.initialPoseList!);
      } else if (_activeCategory != null) {
        _carouselPoses = poseProvider.posesByCategory(_activeCategory!);
      }
      if (_carouselPoses.isEmpty) {
        _carouselPoses = poseProvider.allPoses;
      }
      if (_currentPose == null && _carouselPoses.isNotEmpty) {
        _currentPose = _carouselPoses.first;
        _activeCategory = _currentPose?.category;
      }
      _initializedPoses = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActivePose());
    }
  }

  void _scrollToActivePose() {
    if (_currentPose == null || !_poseCarouselController.hasClients) return;
    final index = _carouselPoses.indexWhere((p) => p.id == _currentPose!.id);
    if (index != -1) {
      final targetScroll = (index * 60.0) - (MediaQuery.of(context).size.width / 2) + 30.0;
      _poseCarouselController.animateTo(
        targetScroll.clamp(0.0, _poseCarouselController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _selectCategory(PoseCategory? category) {
    final poseProvider = Provider.of<PoseProvider>(context, listen: false);
    setState(() {
      _activeCategory = category;
      if (category == null) {
        _carouselPoses = poseProvider.allPoses;
      } else {
        _carouselPoses = poseProvider.posesByCategory(category);
      }
      if (_carouselPoses.isNotEmpty &&
          !_carouselPoses.any((p) => p.id == _currentPose?.id)) {
        _currentPose = _carouselPoses.first;
        _startInstructionRotation();
      }
      _showCategoryPicker = false;
    });
    HapticFeedback.selectionClick();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActivePose());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _countdownTimer?.cancel();
    _instructionTimer?.cancel();
    _matchTimer?.cancel();
    _pulseController.dispose();
    _poseCarouselController.dispose();
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
    _instructionTimer?.cancel();
    _currentInstructionIndex = 0;
    if (_currentPose == null || _currentPose!.instructions.isEmpty) return;
    _instructionTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _currentPose != null && _currentPose!.instructions.isNotEmpty) {
        setState(() {
          _currentInstructionIndex =
              (_currentInstructionIndex + 1) % _currentPose!.instructions.length;
        });
      }
    });
  }

  void _startPoseMatchEngine() {
    final rnd = Random();
    _matchTimer = Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (!mounted) return;
      final fluctuation = (rnd.nextDouble() * 12.0) - 5.0;
      final newPercentage = (_matchPercentage + fluctuation).clamp(42.0, 96.0);

      setState(() {
        _matchPercentage = newPercentage;
      });

      if (_matchPercentage >= 80.0) {
        _consecutiveMatchedFrames++;
        if (!_hasTriggeredHaptic) {
          HapticFeedback.mediumImpact();
          _hasTriggeredHaptic = true;
        }

        if (_autoCaptureOnMatch && _consecutiveMatchedFrames >= 3 && !_isCapturing) {
          _consecutiveMatchedFrames = 0;
          _onCapturePressed();
        }
      } else {
        _consecutiveMatchedFrames = 0;
        _hasTriggeredHaptic = false;
      }
    });
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _hasPermission = false);
      return;
    }
    setState(() => _hasPermission = true);

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      await _setupCamera(_cameras[_currentCameraIndex]);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _setupCamera(CameraDescription description) async {
    _cameraController = CameraController(
      description,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera setup error: $e');
    }
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    setState(() => _isCameraInitialized = false);
    await _cameraController?.dispose();
    await _setupCamera(_cameras[_currentCameraIndex]);
  }

  void _toggleFlash() async {
    if (_cameraController == null) return;
    try {
      _isFlashOn = !_isFlashOn;
      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      setState(() {});
    } catch (e) {
      debugPrint('Flash error: $e');
    }
  }

  void _onCapturePressed() {
    if (_isCapturing) return;

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

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdownValue--;
      });

      if (_countdownValue <= 0) {
        timer.cancel();
        setState(() => _isCountingDown = false);
        _capturePhoto();
      }
    });
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final file = await _cameraController!.takePicture();
      await _processCapturedImage(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF00E676)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _enableDateStamp
                        ? "Saved with Y2K Date Stamp ('26 11 17) to Gallery!"
                        : 'Saved to Gallery!',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E2230),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _processCapturedImage(String imagePath) async {
    final bytes = await img.readFile(imagePath);
    if (bytes == null) return;
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return;

    if (_currentCameraIndex == 1) {
      image = img.flipHorizontal(image);
    }

    switch (_currentFilter) {
      case VintageFilter.noirFilm:
        image = img.grayscale(image);
        image = img.contrast(image, contrast: 115);
        break;
      case VintageFilter.kodakGold:
        image = img.colorOffset(image, red: 20, green: 10, blue: -10);
        image = img.adjustColor(image, saturation: 1.25);
        break;
      case VintageFilter.y2kDigicam:
        image = img.colorOffset(image, red: 10, green: 5, blue: 18);
        image = img.contrast(image, contrast: 108);
        break;
      case VintageFilter.none:
        break;
    }

    if (_enableDateStamp) {
      final dateStr = _getDateStampString();
      final font = img.arial48;
      final x = image.width - 340;
      final y = image.height - 110;

      img.drawString(
        image,
        dateStr,
        font: font,
        x: x + 2,
        y: y + 2,
        color: img.ColorRgb8(120, 40, 0),
      );

      img.drawString(
        image,
        dateStr,
        font: font,
        x: x,
        y: y,
        color: img.ColorRgb8(255, 138, 0),
      );
    }

    final processedBytes = Uint8List.fromList(img.encodeJpg(image, quality: 92));
    await ImageGallerySaverPlus.saveImage(
      processedBytes,
      name: 'PoseIt_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  String _getDateStampString() {
    final now = DateTime.now();
    final year = (now.year % 100).toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return "'$year $month $day";
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

  void _showInstructionModal() {
    if (_currentPose == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161922),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _currentPose!.name,
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
                _currentPose!.description,
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
              ..._currentPose!.instructions.asMap().entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
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
              ? const Color(0xFFFF5252).withValues(alpha: 0.3)
              : Colors.black54,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF5252) : Colors.white24,
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

  Widget _buildCategoryPill(String label, PoseCategory? category) {
    final isSelected = _activeCategory == category;
    return GestureDetector(
      onTap: () => _selectCategory(category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF5252)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
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
              ? const Color(0xFFFF5252).withValues(alpha: 0.35)
              : Colors.black54,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF5252) : Colors.white24,
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

  String _timerLabel(int seconds) {
    if (seconds == 0) return 'Off';
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              const Text(
                'Camera permission is required',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initCamera,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5252),
                ),
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ),
      );
    }

    final isMatched = _matchPercentage >= 80.0;
    final matchColor = isMatched ? const Color(0xFF00E676) : const Color(0xFFFFC107);
    final activePose = _currentPose;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Preview with Real-Time Vintage Filter
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
                    color: const Color(0xFF00E676).withValues(alpha: 0.4),
                    width: 4,
                  ),
                ),
              ),
            ),

          // 2. SVG Human Line-Art Overlay (SOVS Style with Mirror Flip Support)
          if (_isCameraInitialized && activePose != null)
            Builder(
              builder: (context) {
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
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(_isSilhouetteFlipped ? pi : 0),
                        child: Opacity(
                          opacity: _silhouetteOpacity,
                          child: Container(
                            width: overlayWidth,
                            height: overlayHeight,
                            decoration: isMatched
                                ? BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00E676).withValues(alpha: 0.35),
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
                                // Dark drop-shadow outline for 100% visibility on bright daylight
                                SvgPicture.asset(
                                  activePose.svgAssetPath,
                                  fit: BoxFit.contain,
                                  colorFilter: const ColorFilter.mode(
                                    Colors.black87,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                // Primary crisp silhouette line-art (white or matched green)
                                SvgPicture.asset(
                                  activePose.svgAssetPath,
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
                  ),
                );
              },
            ),

          // 3. Anatomical Mapping Aids (Eye-level, Center, and Ground lines)
          if (_showMappingGuides && _isCameraInitialized)
            IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: 130,
                    bottom: 180,
                    left: MediaQuery.of(context).size.width / 2,
                    child: Container(
                      width: 1,
                      color: Colors.white12,
                    ),
                  ),
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
                            color: const Color(0xFF80D8FF).withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 4. Vintage Quartz Orange Date Stamp
          if (_enableDateStamp && _isCameraInitialized)
            Positioned(
              bottom: 175,
              right: 18,
              child: IgnorePointer(
                child: Text(
                  _getDateStampString(),
                  style: const TextStyle(
                    color: Color(0xFFFF8A00),
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

          // 5. Countdown overlay
          if (_isCountingDown)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
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

          // 6. Top Bar (SOVS Minimalist Style)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black38,
                      ),
                    ),
                    Text(
                      activePose?.name ?? 'Pose Guide',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        // Timer toggle
                        IconButton(
                          onPressed: () {
                            final options = SettingsProvider.timerOptions;
                            final nextIndex =
                                (options.indexOf(_selectedTimerSeconds) + 1) %
                                    options.length;
                            setState(
                                () => _selectedTimerSeconds = options[nextIndex]);
                            HapticFeedback.selectionClick();
                          },
                          icon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer,
                                  color: Colors.white, size: 18),
                              if (_selectedTimerSeconds > 0)
                                Text(
                                  ' ${_timerLabel(_selectedTimerSeconds)}',
                                  style: const TextStyle(
                                    color: Color(0xFFFF5252),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.black38),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() =>
                                _showMappingGuides = !_showMappingGuides);
                            HapticFeedback.selectionClick();
                          },
                          icon: Icon(
                            _showMappingGuides ? Icons.grid_on : Icons.grid_off,
                            color: _showMappingGuides
                                ? const Color(0xFF00E676)
                                : Colors.white,
                            size: 20,
                          ),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.black38),
                        ),
                        IconButton(
                          onPressed: _toggleFlash,
                          icon: Icon(
                            _isFlashOn ? Icons.flash_on : Icons.flash_off,
                            color: _isFlashOn
                                ? const Color(0xFFFFD700)
                                : Colors.white,
                            size: 20,
                          ),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.black38),
                        ),
                        IconButton(
                          onPressed: _switchCamera,
                          icon: const Icon(Icons.cameraswitch,
                              color: Colors.white, size: 20),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.black38),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 7. REAL-TIME POSE MATCH METER & STEP CUES
          if (_isCameraInitialized && activePose != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 48,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: matchColor.withValues(alpha: 0.8),
                    width: isMatched ? 2 : 1,
                  ),
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
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'POSE MATCH',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: matchColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_matchPercentage.toInt()}%',
                            style: TextStyle(
                              color: matchColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _matchPercentage / 100.0,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(matchColor),
                        minHeight: 4,
                      ),
                    ),
                    if (activePose.instructions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _showInstructionModal,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Step ${_currentInstructionIndex + 1}: ',
                                style: TextStyle(
                                  color: matchColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  activePose.instructions[_currentInstructionIndex],
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
                  ],
                ),
              ),
            ),

          // 8. Category & Filter Switcher (SOVS 3-circle button popup)
          if (_showCategoryPicker && _isCameraInitialized)
            Positioned(
              bottom: 168,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category Selection Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCategoryPill('ALL', null),
                        _buildCategoryPill('WOMEN', PoseCategory.girl),
                        _buildCategoryPill('MEN', PoseCategory.boy),
                        _buildCategoryPill('COUPLE', PoseCategory.couple),
                        _buildCategoryPill('AESTHETIC', PoseCategory.aesthetic),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 14),
                    // Filter Presets Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
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
                  ],
                ),
              ),
            ),

          // 9. Coral-Red Silhouette Opacity Slider & Framing Presets (SOVS layout)
          if (_showSilhouetteSlider && _isCameraInitialized)
            Positioned(
              bottom: 168,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quick Framing Chips
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
                    const SizedBox(height: 6),
                    // Opacity Slider
                    Row(
                      children: [
                        const Icon(Icons.opacity, color: Color(0xFFFF5252), size: 18),
                        const SizedBox(width: 4),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFFF5252),
                              inactiveTrackColor: Colors.white24,
                              thumbColor: const Color(0xFFFF5252),
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _silhouetteOpacity,
                              min: 0.15,
                              max: 1.0,
                              onChanged: (val) {
                                setState(() => _silhouetteOpacity = val);
                              },
                            ),
                          ),
                        ),
                        Text(
                          '${(_silhouetteOpacity * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // 10. In-Camera Horizontal Pose Carousel (SOVS signature layout, Image 2)
          if (_isCameraInitialized && _carouselPoses.isNotEmpty)
            Positioned(
              bottom: 96,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 64,
                child: ListView.builder(
                  controller: _poseCarouselController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: _carouselPoses.length,
                  itemBuilder: (context, index) {
                    final p = _carouselPoses[index];
                    final isSelected = activePose?.id == p.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentPose = p;
                          _currentInstructionIndex = 0;
                        });
                        _startInstructionRotation();
                        HapticFeedback.selectionClick();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 52,
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFFF5252) : Colors.transparent,
                            width: isSelected ? 2.5 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? const Color(0xFFFF5252).withValues(alpha: 0.4)
                                  : Colors.black26,
                              blurRadius: isSelected ? 8 : 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(6),
                        child: SvgPicture.asset(
                          p.svgAssetPath,
                          fit: BoxFit.contain,
                          colorFilter: const ColorFilter.mode(
                            Colors.black87,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // 11. Bottom Controls Bar (SOVS signature design, Image 2)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Container(
                height: 92,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left Button: 3-circle Venn icon (Categories / Filters, Image 2)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showCategoryPicker = !_showCategoryPicker;
                          _showSilhouetteSlider = false;
                        });
                        HapticFeedback.selectionClick();
                      },
                      icon: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.filter_vintage, color: Colors.white, size: 28),
                          if (_showCategoryPicker)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF5252),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Center: Shutter Button (SOVS Coral Red Target with glowing match feedback)
                    GestureDetector(
                      onTap: _onCapturePressed,
                      child: isMatched
                          ? ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF00E676),
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E676).withValues(alpha: 0.5),
                                      blurRadius: 18,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF00E676),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.black87,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              width: 74,
                              height: 74,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  width: 4,
                                ),
                                color: Colors.white.withValues(alpha: 0.15),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 58,
                                  height: 58,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFFF5252),
                                  ),
                                  child: _isCapturing
                                      ? const Center(
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 26,
                                        ),
                                ),
                              ),
                            ),
                    ),

                    // Right Button: Silhouette Controls (Flip mirror + Opacity slider toggle)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isSilhouetteFlipped = !_isSilhouetteFlipped;
                            });
                            HapticFeedback.selectionClick();
                          },
                          icon: Icon(
                            Icons.flip,
                            color: _isSilhouetteFlipped ? const Color(0xFFFF5252) : Colors.white,
                            size: 24,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showSilhouetteSlider = !_showSilhouetteSlider;
                              _showCategoryPicker = false;
                            });
                            HapticFeedback.selectionClick();
                          },
                          icon: Icon(
                            Icons.tune,
                            color: _showSilhouetteSlider ? const Color(0xFFFF5252) : Colors.white,
                            size: 24,
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
}
