/// Number of distinct colors a loaded proto contract can show.
///
/// The presentation palette has exactly `count` entries. Successive entries are opposing colors.
/// A contract beyond `count` shares a color until removing other contracts frees one.
public enum ContractColorPalette: Sendable {
    public static let count = 8
}
