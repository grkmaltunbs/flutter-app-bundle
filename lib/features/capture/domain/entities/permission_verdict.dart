/// The outcome of a camera-permission check or request.
///
/// Permissions are values, not failures (D3): a denial is an expected state
/// the UI renders, never an exception the data layer throws.
enum PermissionVerdict {
  /// Access is granted (includes limited/provisional grants).
  granted,

  /// Access was denied but the system prompt can still be shown again.
  denied,

  /// Access is denied for good — only the system Settings app can change it.
  permanentlyDenied,
}
