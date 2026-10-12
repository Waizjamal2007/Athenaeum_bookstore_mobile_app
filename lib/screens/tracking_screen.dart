import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../models/store_order.dart';
import '../services/firebase_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/order_summary.dart';

class TrackingScreen extends StatefulWidget {
  final String orderId;
  const TrackingScreen({super.key, required this.orderId});
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late final stream = FirebaseService.orders.child(widget.orderId).onValue;
  @override
  Widget build(BuildContext context) => StoreScaffold(
    title: 'Track order',
    index: 4,
    body: StreamBuilder<DatabaseEvent>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(
            child: Text(
              'Unable to load tracking. Please check your connection.',
            ),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final raw = snapshot.data!.snapshot.value;
        if (raw is! Map)
          return const Center(child: Text('This order is unavailable.'));
        final order = StoreOrder(
          widget.orderId,
          Map<String, dynamic>.from(raw),
        );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Order ${order.id}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Illustrative delivery route · no GPS tracking',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.status,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(_description(order.stage)),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 168,
                        width: double.infinity,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: order.stage < 0 ? 0 : (order.stage / 3),
                          ),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (_, progress, __) => CustomPaint(
                            painter: _RoutePainter(
                              progress,
                              Theme.of(context).colorScheme,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text('Bookstore'), Text('Your address')],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (int i = 0; i < StoreOrder.statuses.length; i++)
                      _step(context, i, order.stage),
                    if (order.stage < 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Current status: ${order.status}'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            OrderSummary(order: order),
          ],
        );
      },
    ),
  );
  String _description(int stage) => switch (stage) {
    0 => 'Your order has been received by the bookstore.',
    1 => 'Your books are being prepared for dispatch.',
    2 => 'Your order has been handed to the courier.',
    3 => 'Your books have been marked as delivered.',
    _ => 'Please contact the bookstore for an update.',
  };
  Widget _step(BuildContext context, int i, int stage) {
    final completed = stage >= i;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Icon(
                completed ? Icons.check : Icons.circle_outlined,
                size: 17,
                color: completed
                    ? Theme.of(context).colorScheme.onPrimary
                    : null,
              ),
            ),
            if (i < 3)
              Container(
                height: 26,
                width: 2,
                color: stage > i
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              StoreOrder.statuses[i],
              style: TextStyle(
                fontWeight: stage == i ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
        if (stage == i)
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Text('Current', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}

class _RoutePainter extends CustomPainter {
  final double progress;
  final ColorScheme colors;
  _RoutePainter(this.progress, this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = colors.surfaceContainerHighest,
    );
    final grid = Paint()
      ..color = colors.outlineVariant.withValues(alpha: .5)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 38) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path()
      ..moveTo(25, size.height * .75)
      ..cubicTo(
        size.width * .4,
        size.height * .9,
        size.width * .5,
        size.height * .15,
        size.width - 25,
        size.height * .25,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = colors.outlineVariant
        ..strokeCap = StrokeCap.round,
    );
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = colors.primary
        ..strokeCap = StrokeCap.round,
    );
    final position =
        metric.getTangentForOffset(metric.length * progress)?.position ??
        Offset(25, size.height * .75);
    for (final p in [
      Offset(25, size.height * .75),
      Offset(size.width - 25, size.height * .25),
    ]) {
      canvas.drawCircle(p, 7, Paint()..color = colors.primary);
    }
    canvas.drawCircle(
      position,
      12,
      Paint()..color = colors.primary.withValues(alpha: .22),
    );
    canvas.drawCircle(position, 6, Paint()..color = colors.primary);
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.progress != progress || old.colors != colors;
}
