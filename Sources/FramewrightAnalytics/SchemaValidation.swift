func validateSchemaInteger(_ value: Int?, field: String) throws {
    if let value, Int32(exactly: value) == nil {
        throw AnalyticsValidationError.invalidField(field)
    }
}
