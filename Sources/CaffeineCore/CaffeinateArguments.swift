public func caffeinateArguments(mode: CaffeinateMode, preset: CaffeinatePreset) -> [String] {
    var args = mode.flags
    if let seconds = preset.seconds {
        args.append("-t")
        args.append(String(seconds))
    }
    return args
}
