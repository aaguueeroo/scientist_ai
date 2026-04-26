class ApiErrorDto {
  const ApiErrorDto({
    required this.code,
    required this.message,
    this.details,
    this.requestId,
  });

  factory ApiErrorDto.fromJson(Map<String, dynamic> json) {
    return ApiErrorDto(
      code: json['code'] as String? ?? 'internal_error',
      message: json['message'] as String? ?? 'Unknown error.',
      details: json['details'],
      requestId: json['request_id'] as String?,
    );
  }

  final String code;
  final String message;
  final dynamic details;
  final String? requestId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'code': code,
      'message': message,
      if (details != null) 'details': details,
      if (requestId != null) 'request_id': requestId,
    };
  }
}
