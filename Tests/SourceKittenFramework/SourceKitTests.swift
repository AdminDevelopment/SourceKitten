//
//  SourceKitTests.swift
//  SourceKitten
//
//  Created by JP Simard on 7/15/15.
//  Copyright © 2015 SourceKitten. All rights reserved.
//

import Foundation
@testable import SourceKittenFramework
import XCTest

private func run(_ executable: String, arguments: [String]) -> String? {
    let task = Process()
    task.launchPath = executable
    task.arguments = arguments

    let pipe = Pipe()
    task.standardOutput = pipe

    task.launch()

    let file = pipe.fileHandleForReading
    let output = String(data: file.readDataToEndOfFile(), encoding: .utf8)
    file.closeFile()
    return output
}

private func sourcekitStringsStartingWith(_ pattern: String) -> Set<String> {
    let sourceKitServicePath = (((run("/usr/bin/xcrun", arguments: ["-f", "swiftc"])! as NSString)
        .deletingLastPathComponent as NSString)
        .deletingLastPathComponent as NSString)
        .appendingPathComponent("lib/sourcekitd.framework/XPCServices/SourceKitService.xpc/Contents/MacOS/SourceKitService")
    let strings = run("/usr/bin/strings", arguments: [sourceKitServicePath])
    return Set(strings!.components(separatedBy: "\n").filter { string in
        return string.range(of: pattern)?.lowerBound == string.startIndex
    })
}

class SourceKitTests: XCTestCase {

    func testStatementKinds() {
        let expected: [StatementKind] = [
            .Brace,
            .Case,
            .For,
            .ForEach,
            .Guard,
            .If,
            .RepeatWhile,
            .Switch,
            .While,
        ]

        let actual = sourcekitStringsStartingWith("source.lang.swift.stmt.")
        let expectedStrings = Set(expected.map { $0.rawValue })
        XCTAssertEqual(
            actual,
            expectedStrings
        )
        if actual != expectedStrings {
            print("the following strings were added: \(actual.subtracting(expectedStrings))")
            print("the following strings were removed: \(expectedStrings.subtracting(actual))")
        }
    }

    func testSyntaxKinds() {
        let expected: [SyntaxKind] = [
            .Argument,
            .AttributeBuiltin,
            .AttributeID,
            .BuildconfigID,
            .BuildconfigKeyword,
            .Comment,
            .CommentMark,
            .CommentURL,
            .DocComment,
            .DocCommentField,
            .Identifier,
            .Keyword,
            .Number,
            .ObjectLiteral,
            .Parameter,
            .Placeholder,
            .String,
            .StringInterpolationAnchor,
            .Typeidentifier
        ]
        let actual = sourcekitStringsStartingWith("source.lang.swift.syntaxtype.")
        let expectedStrings = Set(expected.map { $0.rawValue })
        XCTAssertEqual(
            actual,
            expectedStrings
        )
        if actual != expectedStrings {
            print("the following strings were added: \(actual.subtracting(expectedStrings))")
            print("the following strings were removed: \(expectedStrings.subtracting(actual))")
        }
    }

    func testSwiftDeclarationKind() {
        let expected: [SwiftDeclarationKind] = [
            .Associatedtype,
            .Class,
            .Enum,
            .Enumcase,
            .Enumelement,
            .Extension,
            .ExtensionClass,
            .ExtensionEnum,
            .ExtensionProtocol,
            .ExtensionStruct,
            .FunctionAccessorAddress,
            .FunctionAccessorDidset,
            .FunctionAccessorGetter,
            .FunctionAccessorMutableaddress,
            .FunctionAccessorSetter,
            .FunctionAccessorWillset,
            .FunctionConstructor,
            .FunctionDestructor,
            .FunctionFree,
            .FunctionMethodClass,
            .FunctionMethodInstance,
            .FunctionMethodStatic,
            .FunctionOperatorInfix,
            .FunctionOperatorPostfix,
            .FunctionOperatorPrefix,
            .FunctionSubscript,
            .GenericTypeParam,
            .Module,
            .PrecedenceGroup,
            .Protocol,
            .Struct,
            .Typealias,
            .VarClass,
            .VarGlobal,
            .VarInstance,
            .VarLocal,
            .VarParameter,
            .VarStatic
        ]
        let actual = sourcekitStringsStartingWith("source.lang.swift.decl.")
        let expectedStrings = Set(expected.map { $0.rawValue })
        XCTAssertEqual(
            actual,
            expectedStrings
        )
        if actual != expectedStrings {
            print("the following strings were added: \(actual.subtracting(expectedStrings))")
            print("the following strings were removed: \(expectedStrings.subtracting(actual))")
        }
    }

    func testLibraryWrappersAreUpToDate() {
        let sourceKittenFrameworkModule = Module(xcodeBuildArguments: ["-workspace", "SourceKitten.xcworkspace", "-scheme", "SourceKittenFramework"], name: nil, inPath: projectRoot)!
        let modules: [(module: String, path: String, spmModule: String)] = [
            ("CXString", "libclang.dylib", "Clang_C"),
            ("Documentation", "libclang.dylib", "Clang_C"),
            ("Index", "libclang.dylib", "Clang_C"),
            ("sourcekitd", "sourcekitd.framework/Versions/A/sourcekitd", "SourceKit")
        ]
        for (module, path, spmModule) in modules {
            let wrapperPath = "\(projectRoot)/Source/SourceKittenFramework/library_wrapper_\(module).swift"
            let existingWrapper = try! String(contentsOfFile: wrapperPath)
            let generatedWrapper = libraryWrapperForModule(module, loadPath: path, spmModule: spmModule, compilerArguments: sourceKittenFrameworkModule.compilerArguments)
            XCTAssertEqual(existingWrapper, generatedWrapper)
            let overwrite = false // set this to true to overwrite existing wrappers with the generated ones
            if existingWrapper != generatedWrapper && overwrite {
                try! generatedWrapper.data(using: .utf8)?.write(to: URL(fileURLWithPath: wrapperPath))
            }
        }
    }

    func testIndex() {
        let file = "\(fixturesDirectory)Bicycle.swift"
        let arguments = ["-sdk", sdkPath(), "-j4", file ]
        let indexJSON = NSMutableString(string: toJSON(toNSDictionary(Request.Index(file: file, arguments: arguments).send())) + "\n")

        func replace(_ pattern: String, withTemplate template: String) {
            _ = try! NSRegularExpression(pattern: pattern, options: []).replaceMatches(in: indexJSON, options: [], range: NSRange(location: 0, length: indexJSON.length), withTemplate: template)
        }

        // Replace the parts of the output that are dependent on the environment of the test running machine
        replace("\"key\\.filepath\"[^\\n]*", withTemplate: "\"key\\.filepath\" : \"\",")
        replace("\"key\\.hash\"[^\\n]*", withTemplate: "\"key\\.hash\" : \"\",")

        compareJSONStringWithFixturesName("BicycleIndex", jsonString: indexJSON as String)
    }
}
