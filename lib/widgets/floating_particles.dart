import 'dart:math' as math;
import 'package:flutter/material.dart';

class WaveParticles extends StatefulWidget {
  final int particleCount;
  final double minParticleSize;
  final double maxParticleSize;
  final List<Color> particleColors;
  final double animationSpeed;
  final double waveAmplitude;
  final double waveFrequency;

  const WaveParticles({
    super.key,
    this.particleCount = 20,
    this.minParticleSize = 4.0,
    this.maxParticleSize = 10.0,
    this.particleColors = const [Colors.amber, Colors.greenAccent, Colors.blueAccent],
    this.animationSpeed = 1.0,
    this.waveAmplitude = 50.0,
    this.waveFrequency = 0.5,
  });

  @override
  State<WaveParticles> createState() => _WaveParticlesState();
}

class _WaveParticlesState extends State<WaveParticles> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final math.Random _random = math.Random();

  // Store initial particle offsets for consistent looping
  late List<Offset> _initialOffsets;
  late List<double> _phaseOffsets;

  @override
  void initState() {
    super.initState();
    // Initialize random offsets and phases for each particle
    _initialOffsets = List.generate(
      widget.particleCount,
          (index) => Offset(_random.nextDouble(), _random.nextDouble()),
    );
    _phaseOffsets = List.generate(
      widget.particleCount,
          (index) => _random.nextDouble() * 2 * math.pi,
    );

    _controller = AnimationController(
      duration: Duration(seconds: (10 / widget.animationSpeed).round()),
      vsync: this,
    )..repeat(); // Seamless looping
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final size = MediaQuery.of(context).size;

        return Stack(
          children: List.generate(widget.particleCount, (index) {
            // Normalize animation value to 0-1 for seamless looping
            final t = (_animation.value + _phaseOffsets[index]) % 1.0;
            // Calculate particle position
            // X moves linearly across screen, looping seamlessly
            final x = (t * size.width) % size.width;
            // Y follows a wave pattern with random phase
            final y = size.height * _initialOffsets[index].dy +
                math.sin(t * 2 * math.pi * widget.waveFrequency + _phaseOffsets[index]) * widget.waveAmplitude;

            // Smooth size and opacity transitions
            final particleSize = widget.minParticleSize +
                ((math.cos(t * 2 * math.pi + _phaseOffsets[index]) + 1) / 2) *
                    (widget.maxParticleSize - widget.minParticleSize);
            final opacity = 0.3 + (math.cos(t * 2 * math.pi + _phaseOffsets[index]) * 0.2); // Lower base opacity

            // Select color from provided list
            final color = widget.particleColors[index % widget.particleColors.length];

            return Positioned(
              left: x,
              top: y,
              child: Transform.scale(
                scale: 1.0 + (math.cos(t * 2 * math.pi + _phaseOffsets[index]) * 0.2), // Subtle scaling for glow
                child: Container(
                  width: particleSize,
                  height: particleSize,
                  decoration: BoxDecoration(
                    color: color.withOpacity(opacity.clamp(0.0, 1.0)), // Lower opacity for blur emphasis
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4), // Softer shadow opacity
                        blurRadius: particleSize * 3.0, // Increased blur for dreamy effect
                        spreadRadius: particleSize * 1.2, // Increased spread for wider glow
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}