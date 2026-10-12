/// Model representing an item from the public.onboarding_questions table.
class OnboardingQuestion {
  final String id;
  final String code;
  final String questionText;
  final int displayOrder;
  final bool isActive;

  const OnboardingQuestion({
    required this.id,
    required this.code,
    required this.questionText,
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory OnboardingQuestion.fromJson(Map<String, dynamic> json) {
    return OnboardingQuestion(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      questionText: json['question_text'] as String? ?? '',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'question_text': questionText,
    'display_order': displayOrder,
    'is_active': isActive,
  };
}
