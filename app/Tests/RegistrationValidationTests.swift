import Foundation

// Run with RegistrationValidation.swift using swiftc; no simulator is required.
@main
struct RegistrationValidationTests {
    static func main() throws {
        precondition(RegistrationValidation.requiredError(" \n", title: "名字") != nil)
        precondition(RegistrationValidation.requiredError(" 豆花 ", title: "名字") == nil)
        try RegistrationValidation.validate(ownerName: "小安", petName: "豆花", breed: "博美", socialStyle: "先觀察")
        let missingFields = [
            ("", "豆花", "博美", "先觀察"),
            ("小安", "", "博美", "先觀察"),
            ("小安", "豆花", "", "先觀察"),
            ("小安", "豆花", "博美", "")
        ]
        for values in missingFields {
            do {
                try RegistrationValidation.validate(ownerName: values.0, petName: values.1, breed: values.2, socialStyle: values.3)
                preconditionFailure("Invalid submission was accepted")
            } catch let error as RegistrationSubmissionError {
                precondition(!error.localizedDescription.isEmpty)
            }
        }
        precondition(RegistrationValidation.selectionError(false, title: "體型") != nil)
        precondition(RegistrationValidation.selectionError(true, title: "體型") == nil)
        precondition(RegistrationFailure(error: URLError(.notConnectedToInternet)) == .offline)
        precondition(RegistrationFailure(error: URLError(.networkConnectionLost)) == .offline)
        precondition(RegistrationFailure(error: URLError(.timedOut)) == .timedOut)
        precondition(RegistrationFailure(error: URLError(.badServerResponse)) == .serviceUnavailable)
        precondition(RegistrationFailure(error: RegistrationSubmissionError(message: "請填寫名字")) == .validation("請填寫名字"))
        precondition(RegistrationFailure.timedOut.message.contains("尚未收到"))
        print("Registration validation and error states passed")
    }
}
