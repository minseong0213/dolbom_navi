import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/drive_data_recorder.dart';

const _ink = Color(0xFF17171B);
const _muted = Color(0xFF8B8B94);
const _line = Color(0xFFECECF0);
const _soft = Color(0xFFF5F5F8);
const _pink = Color(0xFFFF4D8D);
const _pinkSoft = Color(0xFFFFE9F2);

class DriveTestScreen extends StatefulWidget {
  const DriveTestScreen({
    super.key,
    required this.onExit,
  });

  final VoidCallback onExit;

  @override
  State<DriveTestScreen> createState() => _DriveTestScreenState();
}

class _DriveTestScreenState extends State<DriveTestScreen> {
  late final DriveDataRecorder _recorder;

  @override
  void initState() {
    super.initState();
    _recorder = DriveDataRecorder();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      await _recorder.start();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_recorder.errorMessage ?? '주행 기록을 시작하지 못했습니다.')),
      );
    }
  }

  Future<void> _stop() async {
    await _recorder.stop();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('주행 센서 CSV 저장을 완료했습니다.')),
    );
  }

  Future<void> _exit() async {
    if (_recorder.isRecording) {
      await _recorder.stop();
    }
    if (mounted) {
      widget.onExit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _recorder,
      builder: (context, _) {
        final recording = _recorder.isRecording;
        return ColoredBox(
          color: Colors.white,
          child: SafeArea(
            child: Column(
              children: [
                _Header(
                  state: _recorder.state,
                  onExit: _exit,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LiveSignal(recorder: _recorder),
                        const SizedBox(height: 18),
                        _Metrics(recorder: _recorder),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _pink,
                              disabledBackgroundColor: const Color(0xFFE4E4EA),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed:
                                recording ? _recorder.markManualBump : null,
                            icon: const Icon(Icons.speed_rounded, size: 28),
                            label: const Text(
                              '방지턱 기록',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: recording
                              ? OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFE5325C),
                                    side: const BorderSide(
                                        color: Color(0xFFE5325C)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _stop,
                                  icon: const Icon(Icons.stop_rounded),
                                  label: const Text('기록 종료'),
                                )
                              : FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _ink,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: kIsWeb ? null : _start,
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('실주행 기록 시작'),
                                ),
                        ),
                        if (_recorder.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          _ErrorMessage(message: _recorder.errorMessage!),
                        ],
                        if (_recorder.filePath != null) ...[
                          const SizedBox(height: 18),
                          const Text(
                            '저장 파일',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            _recorder.filePath!,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
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

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.onExit});

  final DriveRecorderState state;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final recording = state == DriveRecorderState.recording;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: '홈으로',
            onPressed: onExit,
            icon: const Icon(Icons.chevron_left_rounded, size: 30),
          ),
          const Expanded(
            child: Text(
              'PART4 주행 데이터',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: recording ? const Color(0xFFFFEBEF) : _soft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  recording
                      ? Icons.fiber_manual_record
                      : Icons.stop_circle_outlined,
                  size: 14,
                  color: recording ? const Color(0xFFE5325C) : _muted,
                ),
                const SizedBox(width: 5),
                Text(
                  recording ? '기록 중' : '대기',
                  style: TextStyle(
                    color: recording ? const Color(0xFFE5325C) : _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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

class _LiveSignal extends StatelessWidget {
  const _LiveSignal({required this.recorder});

  final DriveDataRecorder recorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _pinkSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'USER_ACCELERATION · 50Hz',
            style: TextStyle(
              color: _pink,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _AxisValue(axis: 'X', value: recorder.latestX),
              _AxisValue(axis: 'Y', value: recorder.latestY),
              _AxisValue(axis: 'Z', value: recorder.latestZ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            recorder.nearbyStatus,
            style: const TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AxisValue extends StatelessWidget {
  const _AxisValue({required this.axis, required this.value});

  final String axis;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(axis, style: const TextStyle(color: _muted, fontSize: 11)),
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.recorder});

  final DriveDataRecorder recorder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _Metric(
                label: 'GPS 속도',
                value: '${recorder.speedKmh.toStringAsFixed(1)} km/h'),
            const SizedBox(width: 8),
            _Metric(label: '샘플', value: '${recorder.sampleCount}'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _Metric(label: '수동 라벨', value: '${recorder.manualLabelCount}'),
            const SizedBox(width: 8),
            _Metric(label: 'DB 자동 라벨', value: '${recorder.autoLabelCount}'),
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFB91C3C),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
