import Foundation

extension UnitDuration {
    static let day = UnitDuration(symbol: "d", converter: UnitConverterLinear(coefficient: 86_400))
    static let week = UnitDuration(symbol: "wk", converter: UnitConverterLinear(coefficient: 604_800))
}

extension UnitPressure {
    static let atmosphere = UnitPressure(symbol: "atm", converter: UnitConverterLinear(coefficient: 101_325))
    static let bar = UnitPressure(symbol: "bar", converter: UnitConverterLinear(coefficient: 100_000))
}

extension UnitEnergy {
    static let btu = UnitEnergy(symbol: "BTU", converter: UnitConverterLinear(coefficient: 1_055.056))
}

enum UnitConverter {
    static func unit(forAlias alias: String) -> Dimension? {
        let lower = alias.lowercased().trimmingCharacters(in: .whitespaces)
        guard !lower.isEmpty else { return nil }
        for (aliases, unit) in catalog {
            if aliases.contains(lower) {
                return unit
            }
        }
        return nil
    }

    private static let catalog: [(aliases: [String], unit: Dimension)] = [
        (["m", "meter", "metre", "meters", "metres"], UnitLength.meters),
        (["km", "kilometer", "kilometre", "kilometers"], UnitLength.kilometers),
        (["cm", "centimeter", "centimetre", "centimeters"], UnitLength.centimeters),
        (["mm", "millimeter", "millimetre"], UnitLength.millimeters),
        (["mi", "mile", "miles"], UnitLength.miles),
        (["yd", "yard", "yards"], UnitLength.yards),
        (["ft", "foot", "feet"], UnitLength.feet),
        (["inch", "inches"], UnitLength.inches),
        (["nauticalmile", "nautical miles", "nmi"], UnitLength.nauticalMiles),

        (["m2", "sqm", "squaremeter", "squaremeter", "meters squared"], UnitArea.squareMeters),
        (["km2", "sqkm", "squarekilometer"], UnitArea.squareKilometers),
        (["cm2", "sqcm", "squarecentimeter"], UnitArea.squareCentimeters),
        (["ha", "hectare", "hectares"], UnitArea.hectares),
        (["ac", "acre", "acres"], UnitArea.acres),
        (["ft2", "sqft", "squarefoot", "squarefeet"], UnitArea.squareFeet),
        (["in2", "sqin", "squareinch"], UnitArea.squareInches),
        (["mi2", "sqmi", "squaremile"], UnitArea.squareMiles),

        (["l", "liter", "litre", "liters", "litres"], UnitVolume.liters),
        (["ml", "milliliter", "millilitre"], UnitVolume.milliliters),
        (["m3", "cubicmeter", "cubicmeters", "cubicmetre"], UnitVolume.cubicMeters),
        (["cm3", "cubiccentimeter"], UnitVolume.cubicCentimeters),
        (["gal", "gallon", "gallons"], UnitVolume.gallons),
        (["qt", "quart", "quarts"], UnitVolume.quarts),
        (["pt", "pint", "pints"], UnitVolume.pints),
        (["cup", "cups"], UnitVolume.cups),
        (["tbsp", "tablespoon", "tablespoons"], UnitVolume.tablespoons),
        (["tsp", "teaspoon", "teaspoons"], UnitVolume.teaspoons),
        (["floz", "fluidounce"], UnitVolume.fluidOunces),
        (["imperialgal", "imperialgallon"], UnitVolume.imperialGallons),

        (["c", "celsius", "degc", "centigrade"], UnitTemperature.celsius),
        (["f", "fahrenheit", "degf"], UnitTemperature.fahrenheit),
        (["k", "kelvin", "degk"], UnitTemperature.kelvin),

        (["kmh", "kph", "kilometersperhour"], UnitSpeed.kilometersPerHour),
        (["mph", "milesperhour"], UnitSpeed.milesPerHour),
        (["mps", "m/s", "meterspersecond"], UnitSpeed.metersPerSecond),
        (["kn", "knot", "knots"], UnitSpeed.knots),

        (["s", "sec", "second", "seconds"], UnitDuration.seconds),
        (["ms", "millisecond"], UnitDuration.milliseconds),
        (["min", "minute", "minutes"], UnitDuration.minutes),
        (["h", "hr", "hour", "hours"], UnitDuration.hours),
        (["d", "day", "days"], UnitDuration.day),
        (["w", "week", "weeks"], UnitDuration.week),

        (["j", "joule", "joules"], UnitEnergy.joules),
        (["kcal", "kilocalorie", "kilocalories", "cal", "calorie", "calories"], UnitEnergy.kilocalories),
        (["kwh", "kilowatthour", "kilowatthours", "kilowatt-hour"], UnitEnergy.kilowattHours),
        (["btu"], UnitEnergy.btu),

        (["pa", "pascal", "pascals", "newtonspersquaremeter"], UnitPressure.newtonsPerMetersSquared),
        (["kpa", "kilopascal", "kilopascals"], UnitPressure.kilopascals),
        (["mbar", "millibar", "millibars"], UnitPressure.millibars),
        (["psi", "poundspersquareinch"], UnitPressure.poundsForcePerSquareInch),
        (["mmhg", "millimeterofmercury", "torr"], UnitPressure.millimetersOfMercury),
        (["inHg", "inchesOfMercury"], UnitPressure.inchesOfMercury),
        (["atm", "atmosphere", "atmospheres"], UnitPressure.atmosphere),
        (["bar"], UnitPressure.bar),

        (["rad", "radian", "radians"], UnitAngle.radians),
        (["deg", "degree", "degrees"], UnitAngle.degrees),
        (["grad", "gradian", "gradians"], UnitAngle.gradians),

        (["bit", "bits"], UnitInformationStorage.bits),
        (["b", "byte", "bytes"], UnitInformationStorage.bytes),
        (["kb", "kilobyte"], UnitInformationStorage.kilobytes),
        (["mb", "megabyte"], UnitInformationStorage.megabytes),
        (["gb", "gigabyte"], UnitInformationStorage.gigabytes),
        (["tb", "terabyte"], UnitInformationStorage.terabytes),
        (["kib", "kibibyte"], UnitInformationStorage.kibibytes),
        (["mib", "mebibyte"], UnitInformationStorage.mebibytes),
        (["gib", "gibibyte"], UnitInformationStorage.gibibytes),
        (["tib", "tebibyte"], UnitInformationStorage.tebibytes),
    ]
}