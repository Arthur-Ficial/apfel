import ApfelCore

let errors: [ApfelError] = [
    .rateLimited,
    .contextOverflow,
    .unsupportedLanguage("tlh"),
]

for error in errors {
    print("\(error.cliLabel) \(error.localizedDescription)")
}
