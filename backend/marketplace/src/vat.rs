/// EU VAT rates by ISO 3166-1 alpha-2 country code.
/// Source: European Commission standard rates (2024).
pub fn vat_rate(country_code: &str) -> f64 {
    match country_code.to_uppercase().as_str() {
        "AT" => 0.20, // Austria
        "BE" => 0.21, // Belgium
        "BG" => 0.20, // Bulgaria
        "CY" => 0.19, // Cyprus
        "CZ" => 0.21, // Czech Republic
        "DE" => 0.19, // Germany
        "DK" => 0.25, // Denmark
        "EE" => 0.22, // Estonia
        "ES" => 0.21, // Spain
        "FI" => 0.25, // Finland
        "FR" => 0.20, // France
        "GR" => 0.24, // Greece
        "HR" => 0.25, // Croatia
        "HU" => 0.27, // Hungary
        "IE" => 0.23, // Ireland
        "IT" => 0.22, // Italy
        "LT" => 0.21, // Lithuania
        "LU" => 0.17, // Luxembourg
        "LV" => 0.21, // Latvia
        "MT" => 0.18, // Malta
        "NL" => 0.21, // Netherlands
        "PL" => 0.23, // Poland
        "PT" => 0.23, // Portugal
        "RO" => 0.19, // Romania
        "SE" => 0.25, // Sweden
        "SI" => 0.22, // Slovenia
        "SK" => 0.20, // Slovakia
        // Non-EU EEA
        "NO" => 0.25, // Norway
        "IS" => 0.24, // Iceland
        "LI" => 0.081, // Liechtenstein
        // UK (post-Brexit)
        "GB" => 0.20,
        // Default: EU standard rate
        _ => 0.20,
    }
}

/// Calculate VAT amount in EUR given a net amount and country code.
pub fn calculate_vat(net_eur: f64, country_code: &str) -> f64 {
    net_eur * vat_rate(country_code)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn german_vat_is_19_percent() {
        assert!((vat_rate("DE") - 0.19).abs() < f64::EPSILON);
    }

    #[test]
    fn french_vat_is_20_percent() {
        assert!((vat_rate("FR") - 0.20).abs() < f64::EPSILON);
    }

    #[test]
    fn unknown_country_defaults_to_20_percent() {
        assert!((vat_rate("XX") - 0.20).abs() < f64::EPSILON);
    }

    #[test]
    fn vat_amount_calculation() {
        let vat = calculate_vat(100.0, "DE");
        assert!((vat - 19.0).abs() < 1e-9);
    }
}
