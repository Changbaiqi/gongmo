// ============================================================
// tilt_card.dart（core/widgets · 通用视觉组件）
// 职责：让卡片随手机重力方向做轻微 3D 倾斜，并叠加动态高光与阴影。
// 关联：数据来自 sensors_plus 加速度计；纯展示组件，不依赖控制器，
//       通常包在统计卡、记账卡外层使用。
// ============================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException;
import 'package:sensors_plus/sensors_plus.dart';

/// 跟随手机重力/陀螺仪做轻微 3D 倾斜 + 动态光影的卡片包装。
///
/// - 加速度计获取设备相对重力的倾斜方向，映射为绕 X/Y 轴旋转并做平滑插值；
/// - 表面高光带与边缘高光随倾斜滑动/增强，阴影向倾斜反方向偏移，
///   让 3D 变化更明显；
/// - 稳定后自动停止 ticker，退到后台停止监听以省电；
/// - 若运行环境未注册传感器插件，会静默降级为静态光影，不报错。
///
/// 生命周期：随宿主 Widget 创建/销毁；`enabled` 由 false 变 true 时才开始
/// 监听，适合放在可折叠或懒加载的卡片里按需启用。
class TiltCard extends StatefulWidget {
  const TiltCard({
    super.key,
    required this.child,
    this.maxAngle = 0.08, // 最大旋转弧度（约 4.6°）
    this.enabled = true,
    this.borderRadius = 20,
    this.shadowColor,
    this.shine = true,
  });

  final Widget child;
  final double maxAngle;
  final bool enabled;
  final double borderRadius;

  /// 动态阴影颜色（null 则不绘制阴影）
  final Color? shadowColor;

  /// 是否绘制随倾斜移动的表面高光 / 边缘高光
  final bool shine;

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _sensorChannel =
      MethodChannel('dev.fluttercommunity.plus/sensors/method');

  StreamSubscription<AccelerometerEvent>? _sub;
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<Offset> _tilt = ValueNotifier(Offset.zero);
  Offset _target = Offset.zero;

  bool _listening = false;
  bool _checkedAvailability = false;
  bool _sensorAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.enabled) _listen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _ticker.dispose();
    _tilt.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;
    if (state == AppLifecycleState.resumed) {
      _listen();
    } else {
      // 退到后台时停止监听传感器并回正，避免耗电
      _stopListen();
    }
  }

  @override
  void didUpdateWidget(covariant TiltCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _listen();
    } else if (!widget.enabled && oldWidget.enabled) {
      _stopListen();
    }
  }

  Future<void> _listen() async {
    if (_listening) return;
    _listening = true;

    // 先探测插件是否可用，避免在未注册插件的环境里抛出 MissingPluginException
    if (!_checkedAvailability) {
      _checkedAvailability = true;
      try {
        await _sensorChannel.invokeMethod<void>(
            'setAccelerationSamplingPeriod', 20000);
        _sensorAvailable = true;
      } on MissingPluginException {
        _sensorAvailable = false;
      } catch (_) {
        _sensorAvailable = true;
      }
    }
    if (!_sensorAvailable) {
      _listening = false;
      return;
    }

    try {
      _sub?.cancel();
      _sub = accelerometerEventStream().listen(_onData, onError: (_) {});
    } catch (_) {
      _sub = null;
      _listening = false;
    }
  }

  /// 停止监听并把目标角度归零；启动 ticker 让卡片平滑回正（而非闪回）
  void _stopListen() {
    _sub?.cancel();
    _sub = null;
    _listening = false;
    _target = Offset.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  void _onData(AccelerometerEvent e) {
    // 加速度计静止时反映重力方向：竖屏正持时 y≈9.8、x≈0。
    // 归一化到 -1..1（±4.5 m/s² 视为最大倾角）
    const range = 4.5;
    _target = Offset(
      (e.x / range).clamp(-1.0, 1.0),
      (e.y / range).clamp(-1.0, 1.0),
    );
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration _) {
    const k = 0.14; // 平滑系数
    final cur = _tilt.value;
    final next = Offset(
      cur.dx + (_target.dx - cur.dx) * k,
      cur.dy + (_target.dy - cur.dy) * k,
    );
    if ((next - _target).distance < 0.002) {
      _tilt.value = _target;
      _ticker.stop(); // 稳定后停止，避免常驻逐帧刷新
    } else {
      _tilt.value = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset>(
      valueListenable: _tilt,
      child: widget.child,
      builder: (context, tilt, child) {
        final dx = tilt.dx.clamp(-1.0, 1.0);
        final dy = tilt.dy.clamp(-1.0, 1.0);
        final mag = tilt.distance.clamp(0.0, 1.0);

        Widget content = child!;

        if (widget.shine) {
          content = Stack(
            children: [
              content,
              Positioned.fill(
                child: IgnorePointer(
                  child: _ShineOverlay(
                    dx: dx,
                    dy: dy,
                    mag: mag,
                    radius: widget.borderRadius,
                  ),
                ),
              ),
            ],
          );
        }

        if (dx != 0 || dy != 0) {
          content = Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012) // 透视：数值越小透视越强，营造近大远小
              ..rotateY(dx * widget.maxAngle)
              ..rotateX(-dy * widget.maxAngle), // 屏幕 y 向下与旋转方向相反
            child: content,
          );
        }

        final shadow = widget.shadowColor;
        if (shadow == null) return content;

        // 阴影朝倾斜反方向轻微偏移；幅度收敛，避免滚动时因手机微倾
        // 导致阴影忽大忽亮（看起来像发光）
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: shadow,
                offset: Offset(-dx * 4, 5 - dy * 3),
                blurRadius: 16 + mag * 6,
              ),
            ],
          ),
          child: content,
        );
      },
    );
  }
}

/// 表面高光带 + 边缘高光：随倾斜方向滑动、朝光源一侧更亮
class _ShineOverlay extends StatelessWidget {
  const _ShineOverlay({
    required this.dx,
    required this.dy,
    required this.mag,
    required this.radius,
  });

  final double dx;
  final double dy;
  final double mag;
  final double radius;

  @override
  Widget build(BuildContext context) {
    // 光源固定在左上：倾斜时高光带随之平移
    final begin = Alignment(-1 + dx, -1 + dy);
    final end = Alignment(1 + dx, 1 + dy);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        // 四边亮度各不相同，BoxDecoration 的 border 不允许与 borderRadius
        // 同时使用（会触发 "borderRadius can only be given on borders with
        // uniform colors" 断言），因此改为按倾斜方向绘制渐变描边
        foregroundPainter:
            _ShineEdgePainter(dx: dx, dy: dy, radius: radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: [
                Colors.white.withValues(alpha: 0.04 + 0.05 * mag),
                Colors.white.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.55],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// 边缘高光描边：用沿倾斜方向的线性渐变模拟原四边差异亮度
class _ShineEdgePainter extends CustomPainter {
  _ShineEdgePainter({
    required this.dx,
    required this.dy,
    required this.radius,
  });

  final double dx;
  final double dy;
  final double radius;

  static const _base = 0.04;
  static const _maxExtra = 0.12;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = (Offset.zero & size).deflate(0.5);
    final dxn = dx.clamp(-1.0, 1.0);
    final dyn = dy.clamp(-1.0, 1.0);
    // 左上 / 右下两个角对应的边缘亮度（与原来的四边取色一致）
    final startAlpha = _base +
        ((-dxn).clamp(0.0, 1.0) + (-dyn).clamp(0.0, 1.0)) / 2 * _maxExtra;
    final endAlpha = _base +
        (dxn.clamp(0.0, 1.0) + dyn.clamp(0.0, 1.0)) / 2 * _maxExtra;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment(-1 + dxn, -1 + dyn),
        end: Alignment(1 + dxn, 1 + dyn),
        colors: [
          Colors.white.withValues(alpha: startAlpha),
          Colors.white.withValues(alpha: endAlpha),
        ],
      ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius - 0.5)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ShineEdgePainter oldDelegate) =>
      oldDelegate.dx != dx ||
      oldDelegate.dy != dy ||
      oldDelegate.radius != radius;
}
