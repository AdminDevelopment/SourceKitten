//
//  Syntax.swift
//  SourceKitten
//
//  Created by JP Simard on 2015-01-07.
//  Copyright (c) 2015 SourceKitten. All rights reserved.
//

import Commandant
import Foundation
import SourceKittenFramework
import Result

struct SyntaxCommand: CommandType {
    let verb = "syntax"
    let function = "Print Swift syntax information as JSON"

    func run(mode: CommandMode) -> Result<(), CommandantError<SourceKittenError>> {
        return SyntaxOptions.evaluate(mode).flatMap { options in
            if options.file.characters.count > 0 {
                if let file = File(path: options.file.absolutePathRepresentation()) {
                    print(SyntaxMap(file: file))
                    return .Success()
                }
                return .Failure(.CommandError(.ReadFailed(path: options.file)))
            }
            if options.text.characters.count > 0 {
                print(SyntaxMap(file: File(contents: options.text)))
                return .Success()
            }
            return .Failure(.CommandError(.InvalidArgument(description: "either file or text must be set when calling syntax")))
        }
    }
}

struct SyntaxOptions: OptionsType {
    let file: String
    let text: String

    static func create(file: String)(text: String) -> SyntaxOptions {
        return self.init(file: file, text: text)
    }

    static func evaluate(m: CommandMode) -> Result<SyntaxOptions, CommandantError<SourceKittenError>> {
        return create
            <*> m <| Option(key: "file", defaultValue: "", usage: "relative or absolute path of Swift file to parse")
            <*> m <| Option(key: "text", defaultValue: "", usage: "Swift code text to parse")
    }
}
