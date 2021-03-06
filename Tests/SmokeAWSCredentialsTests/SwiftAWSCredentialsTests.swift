// Copyright 2018-2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//
//  SmokeAWSCredentialsTests.swift
//  SmokeAWSCredentials
//

import XCTest
@testable import SmokeAWSCredentials
import SecurityTokenClient
import SecurityTokenModel
import SmokeHTTPClient
import SmokeAWSCore

@available(OSX 10.12, *)
private let iso8601DateFormatter = ISO8601DateFormatter()

extension Date {
    var iso8601: String {
        if #available(OSX 10.12, *) {
            return iso8601DateFormatter.string(from: self)
        } else {
            fatalError("Attempting to use ISO8601DateFormatter on an unsupported macOS version.")
        }
    }
}

class SmokeAWSCredentialsTests: XCTestCase {
    func getAssumeRoleSync()
    -> SecurityTokenClientProtocol.AssumeRoleSyncType {
        let expiration = Date(timeIntervalSinceNow: 305)
        let expiryString = expiration.iso8601
        
        func assumeRoleSync(input: SecurityTokenModel.AssumeRoleRequest) throws -> SecurityTokenModel.AssumeRoleResponseForAssumeRole {
            let credentials = SecurityTokenModel.Credentials(accessKeyId: TestVariables.accessKeyId,
                                                             expiration: expiryString,
                                                             secretAccessKey: TestVariables.secretAccessKey,
                                                             sessionToken: TestVariables.sessionToken)
            
            let assumeRoleResult = SecurityTokenModel.AssumeRoleResponse(
                assumedRoleUser: nil,
                credentials: credentials,
                packedPolicySize: nil)
            
            return SecurityTokenModel.AssumeRoleResponseForAssumeRole(assumeRoleResult: assumeRoleResult)
        }
        
        return assumeRoleSync
    }
    
    struct TestExpiringCredentialsRetriever: ExpiringCredentialsRetriever {
        let client: MockSecurityTokenClient
        let roleArn: String
        let roleSessionName: String
        let durationSeconds: Int?
        
        init(assumeRoleSyncOverride: @escaping SecurityTokenClientProtocol.AssumeRoleSyncType,
             roleArn: String,
             roleSessionName: String,
             durationSeconds: Int?,
             retryConfiguration: HTTPClientRetryConfiguration) {
            self.client = MockSecurityTokenClient(assumeRoleSync: assumeRoleSyncOverride)
            self.roleArn = roleArn
            self.roleSessionName = roleSessionName
            self.durationSeconds = durationSeconds
        }
        
        func close() {
            
        }
        
        func wait() {
            
        }
        
        func get() throws -> ExpiringCredentials {
            return try client.getAssumedExpiringCredentials(
                        roleArn: roleArn,
                        roleSessionName: roleSessionName,
                        durationSeconds: durationSeconds)
        }
    }
    
    func testRotatingGetCredentials() throws {
        let credentialsRetriever = TestExpiringCredentialsRetriever(
            assumeRoleSyncOverride: getAssumeRoleSync(),
            roleArn: "arn:aws:iam::XXXXXXXXXXXX:role/theRole",
            roleSessionName: "mySession",
            durationSeconds: 3600,
            retryConfiguration: .default)
        
        let credentials = try credentialsRetriever.get()
        XCTAssertEqual(TestVariables.accessKeyId, credentials.accessKeyId)
        XCTAssertEqual(TestVariables.secretAccessKey, credentials.secretAccessKey)
        XCTAssertEqual(TestVariables.sessionToken, credentials.sessionToken)
        
        credentialsRetriever.close()
        credentialsRetriever.wait()
    }
    
    func testStaticGetCredentials() throws {
        let client = MockSecurityTokenClient(assumeRoleSync: getAssumeRoleSync())
        
        let credentials = try client.getAssumedExpiringCredentials(
                roleArn: "arn:aws:iam::XXXXXXXXXXXX:role/theRole",
                roleSessionName: "mySession",
                durationSeconds: nil)
        XCTAssertEqual(TestVariables.accessKeyId, credentials.accessKeyId)
        XCTAssertEqual(TestVariables.secretAccessKey, credentials.secretAccessKey)
        XCTAssertEqual(TestVariables.sessionToken, credentials.sessionToken)
    }


    static var allTests = [
        ("testRotatingGetCredentials", testRotatingGetCredentials),
        ("testStaticGetCredentials", testStaticGetCredentials)
    ]
}
