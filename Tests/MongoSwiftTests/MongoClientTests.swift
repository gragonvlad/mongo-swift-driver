import mongoc
@testable import MongoSwift
import Nimble
import XCTest

final class MongoClientTests: MongoSwiftTestCase {
    static var allTests: [(String, (MongoClientTests) -> () throws -> Void)] {
        return [
            ("testListDatabases", testListDatabases),
            ("testOpaqueInitialization", testOpaqueInitialization),
            ("testFailedClientInitialization", testFailedClientInitialization)
        ]
    }

    func testListDatabases() throws {
        let client = try MongoClient()
        let databases = try client.listDatabases(options: ListDatabasesOptions(nameOnly: true))
        expect((Array(databases) as [Document]).count).to(beGreaterThan(0))
    }

    func testOpaqueInitialization() throws {
        let connectionString = MongoSwiftTestCase.connStr
        var error = bson_error_t()
        guard let uri = mongoc_uri_new_with_error(connectionString, &error) else {
            throw MongoError.invalidUri(message: toErrorString(error))
        }

        guard let client_t = mongoc_client_new_from_uri(uri) else {
            throw MongoError.invalidClient()
        }

        let client = MongoClient(fromPointer: client_t)
        let db = try client.db("test")
        let coll = try db.collection("foo")
        let insertResult = try coll.insertOne([ "test": 42 ])
        let findResult = try coll.find([ "_id": insertResult!.insertedId ])
        let docs = Array(findResult)
        expect(docs[0]["test"] as? Int).to(equal(42))
        try db.drop()
    }

    func testFailedClientInitialization() {
        // check that we fail gracefully with an error if passing in an invalid URI
        expect(try MongoClient(connectionString: "abcd")).to(throwError())
    }

    func testServerVersion() throws {
        // swiftlint:disable nesting
        typealias Version = MongoClient.ServerVersion
        // swiftlint:enable nesting

        expect(try MongoClient().serverVersion()).toNot(throwError())

        let three6 = Version(major: 3, minor: 6)
        let three61 = Version(major: 3, minor: 6, patch: 1)
        let three7 = Version(major: 3, minor: 7)

        // test equality
        expect(try Version("3.6")).to(equal(three6))
        expect(try Version("3.6.0")).to(equal(three6))
        expect(try Version("3.6.0-rc1")).to(equal(three6))

        expect(try Version("3.6.1")).to(equal(three61))
        expect(try Version("3.6.1.1")).to(equal(three61))

        // lt
        expect(three6.isLessThan(three6)).to(beFalse())
        expect(three6.isLessThan(three61)).to(beTrue())
        expect(three61.isLessThan(three6)).to(beFalse())
        expect(three61.isLessThan(three7)).to(beTrue())
        expect(three7.isLessThan(three6)).to(beFalse())
        expect(three7.isLessThan(three61)).to(beFalse())

        // lte
        expect(three6.isLessThanOrEqualTo(three6)).to(beTrue())
        expect(three6.isLessThanOrEqualTo(three61)).to(beTrue())
        expect(three61.isLessThanOrEqualTo(three6)).to(beFalse())
        expect(three61.isLessThanOrEqualTo(three7)).to(beTrue())
        expect(three7.isLessThanOrEqualTo(three6)).to(beFalse())
        expect(three7.isLessThanOrEqualTo(three61)).to(beFalse())

        // gt
        expect(three6.isGreaterThan(three6)).to(beFalse())
        expect(three6.isGreaterThan(three61)).to(beFalse())
        expect(three61.isGreaterThan(three6)).to(beTrue())
        expect(three61.isGreaterThan(three7)).to(beFalse())
        expect(three7.isGreaterThan(three6)).to(beTrue())
        expect(three7.isGreaterThan(three61)).to(beTrue())

        // gte
        expect(three6.isGreaterThanOrEqualTo(three6)).to(beTrue())
        expect(three6.isGreaterThanOrEqualTo(three61)).to(beFalse())
        expect(three61.isGreaterThanOrEqualTo(three6)).to(beTrue())
        expect(three61.isGreaterThanOrEqualTo(three7)).to(beFalse())
        expect(three7.isGreaterThanOrEqualTo(three6)).to(beTrue())
        expect(three7.isGreaterThanOrEqualTo(three61)).to(beTrue())

        // invalid strings
        expect(try Version("hi")).to(throwError())
        expect(try Version("3")).to(throwError())
        expect(try Version("3.x")).to(throwError())
    }
}
