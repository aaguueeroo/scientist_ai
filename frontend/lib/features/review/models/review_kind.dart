/// Discriminator for [Review] subclasses. Mirrors the `kind` string on the
/// wire (`POST /reviews`, `GET /reviews`).
enum ReviewKind {
  correction,
  comment,
  feedback,
}
