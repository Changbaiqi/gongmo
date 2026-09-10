/// 发票抬头信息（用于开具发票时快速复制填写）
class InvoiceProfile {
  String id;
  String title; // 显示名（如：公司抬头 / 个人）
  String name; // 抬头名称（企业全称或个人姓名）
  String taxId; // 纳税人识别号 / 身份证号
  String address; // 注册地址
  String phone; // 电话
  String bankName; // 开户银行
  String bankAccount; // 银行账号
  DateTime updatedAt;

  InvoiceProfile({
    required this.id,
    this.title = '',
    this.name = '',
    this.taxId = '',
    this.address = '',
    this.phone = '',
    this.bankName = '',
    this.bankAccount = '',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory InvoiceProfile.fromJson(Map<String, dynamic> json) {
    return InvoiceProfile(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      name: json['name'] as String? ?? '',
      taxId: json['taxId'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      bankName: json['bankName'] as String? ?? '',
      bankAccount: json['bankAccount'] as String? ?? '',
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ??
              DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'name': name,
      'taxId': taxId,
      'address': address,
      'phone': phone,
      'bankName': bankName,
      'bankAccount': bankAccount,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
