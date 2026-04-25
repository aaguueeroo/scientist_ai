class ApiErrorDto {
  const ApiErrorDto({
    required this.code,
    required this.message,
  });

  factory ApiErrorDto.fromJson(Map<String, dynamic> json) {
    return ApiErrorDto(
      code: json['code'] as String? ?? 'internal_error',
      message: json['message'] as String? ?? 'Unknown error.',
    );
  }

  final String code;
  final String message;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'code': code,
      'message': message,
    };
  }
}
