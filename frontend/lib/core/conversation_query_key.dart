/// Single canonical string used to match the research question in the UI,
/// [ConversationSessionStore], and server `provenance_query`.
///
/// Trims and collapses all [RegExp] whitespace (newlines, tabs, runs of
/// spaces) to a single space so a sidebar title always matches a stored id.
String conversationQueryKey(String s) {
  return s
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}
