class TimerTag {
  final String id;
  String name;
  String icon;
  String color;
  bool isWork;
  double hourlyRate;
  int sortOrder;

  TimerTag({
    required this.id,
    required this.name,
    this.icon = 'timer',
    this.color = '#2196F3',
    this.isWork = false,
    this.hourlyRate = 0,
    this.sortOrder = 0,
  });

  factory TimerTag.fromJson(Map<String, dynamic> json) {
    return TimerTag(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? 'timer',
      color: json['color'] as String? ?? '#2196F3',
      isWork: json['isWork'] as bool? ?? false,
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 0,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'isWork': isWork,
      'hourlyRate': hourlyRate,
      'sortOrder': sortOrder,
    };
  }

  static List<TimerTag> defaults() {
    return [
      TimerTag(
          id: 'tag_work',
          name: '工作',
          icon: 'work',
          color: '#4CAF50',
          isWork: true,
          hourlyRate: 150,
          sortOrder: 1),
      TimerTag(
          id: 'tag_study',
          name: '学习',
          icon: 'school',
          color: '#2196F3',
          sortOrder: 2),
      TimerTag(
          id: 'tag_rest',
          name: '休息',
          icon: 'self_improvement',
          color: '#FF9800',
          sortOrder: 3),
      TimerTag(
          id: 'tag_exercise',
          name: '运动',
          icon: 'fitness_center',
          color: '#E91E63',
          sortOrder: 4),
      TimerTag(
          id: 'tag_reading',
          name: '阅读',
          icon: 'menu_book',
          color: '#9C27B0',
          sortOrder: 5),
    ];
  }
}
