private enum Arg : CustomStringConvertible {
  /// A positional argument
  case Argument(String)

  /// A boolean like option, `--version`, `--help`, `--no-clean`.
  case Option(String)

  /// A flag
  case Flag(Set<Character>)

  var description:String {
    switch self {
    case .Argument(let value):
      return value
    case .Option(let key):
      return "--\(key)"
    case .Flag(let flags):
      return "-\(String(flags))"
    }
  }

  var type:String {
    switch self {
    case .Argument:
      return "argument"
    case .Option:
      return "option"
    case .Flag:
      return "flag"
    }
  }
}


public struct ArgumentParserError : ErrorProtocol, Equatable, CustomStringConvertible {
  public let description: String

  public init(_ description: String) {
    self.description = description
  }
}


public func ==(lhs: ArgumentParserError, rhs: ArgumentParserError) -> Bool {
  return lhs.description == rhs.description
}


public final class ArgumentParser : ArgumentConvertible, CustomStringConvertible {
  private var arguments:[Arg]

  /// Initialises the ArgumentParser with an array of arguments
  public init(arguments: [String]) {
    self.arguments = arguments.map { argument in
      if argument.characters.first == "-" {
        let start = argument.index(after: argument.startIndex)
        let flags = argument[start ..< argument.endIndex]

        if flags.characters.first == "-" {
          let start = flags.index(after: flags.startIndex)
          let option = flags[start ..< flags.endIndex]
          return .Option(option)
        }

        return .Flag(Set(flags.characters))
      }

      return .Argument(argument)
    }
  }

  public init(parser: ArgumentParser) throws {
    arguments = parser.arguments
  }

  public var description:String {
    return arguments.map { $0.description }.joined(separator: " ")
  }

  public var isEmpty:Bool {
    return arguments.isEmpty
  }

  public var remainder:[String] {
    return arguments.map { $0.description }
  }

  /// Returns the first positional argument in the remaining arguments.
  /// This will remove the argument from the remaining arguments.
  public func shift() -> String? {
    for (index, argument) in arguments.enumerated() {
      switch argument {
      case .Argument(let value):
        arguments.remove(at: index)
        return value
      default:
        continue
      }
    }

    return nil
  }

  /// Returns the value for an option (--name Kyle, --name=Kyle)
  public func shiftValueForOption(_ name: String) throws -> String? {
    return try shiftValuesForOption(name)?.first
  }

  /// Returns the value for an option (--name Kyle, --name=Kyle)
  public func shiftValuesForOption(_ name: String, count: Int = 1) throws -> [String]? {
    var index = 0
    var hasOption = false

    for argument in arguments {
      switch argument {
      case .Option(let option):
        if option == name {
          hasOption = true
          break
        }
        fallthrough
      default:
        index += 1
      }

      if hasOption {
        break
      }
    }

    if hasOption {
      arguments.remove(at: index)  // Pop option
      return try (0..<count).map { i in
        if arguments.count > index {
          let argument = arguments.remove(at: index)
          switch argument {
          case .Argument(let value):
            return value
          default:
            throw ArgumentParserError("Unexpected \(argument.type) `\(argument)` as a value for `--\(name)`")
          }
        }

        throw ArgumentError.MissingValue(argument: "--\(name)")
      }
    }

    return nil
  }

  /// Returns whether an option was specified in the arguments
  public func hasOption(_ name: String) -> Bool {
    var index = 0
    for argument in arguments {
      switch argument {
      case .Option(let option):
        if option == name {
          arguments.remove(at: index)
          return true
        }
      default:
        break
      }

      index += 1
    }

    return false
  }

  /// Returns whether a flag was specified in the arguments
  public func hasFlag(_ flag: Character) -> Bool {
    var index = 0
    for argument in arguments {
      switch argument {
      case .Flag(let option):
        var options = option
        if options.contains(flag) {
          options.remove(flag)
          arguments.remove(at: index)

          if !options.isEmpty {
            arguments.insert(.Flag(options), at: index)
          }
          return true
        }
      default:
        break
      }

      index += 1
    }

    return false
  }

  /// Returns the value for a flag (-n Kyle)
  public func shiftValueForFlag(_ flag: Character) throws -> String? {
    return try shiftValuesForFlag(flag)?.first
  }

  /// Returns the value for a flag (-n Kyle)
  public func shiftValuesForFlag(_ flag: Character, count: Int = 1) throws -> [String]? {
    var index = 0
    var hasFlag = false

    for argument in arguments {
      switch argument {
      case .Flag(let flags):
        if flags.contains(flag) {
          hasFlag = true
          break
        }
        fallthrough
      default:
        index += 1
      }

      if hasFlag {
        break
      }
    }

    if hasFlag {
      arguments.remove(at: index)

      return try (0..<count).map { i in
        if arguments.count > index {
          let argument = arguments.remove(at: index)
          switch argument {
          case .Argument(let value):
            return value
          default:
            throw ArgumentParserError("Unexpected \(argument.type) `\(argument)` as a value for `-\(flag)`")
          }
        }

        throw ArgumentError.MissingValue(argument: "-\(flag)")
      }
    }

    return nil
  }
}
