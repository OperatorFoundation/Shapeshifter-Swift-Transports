//
//  ShadowTests.swift
//  ShadowTests
//
//  Created by Mafalda on 8/3/20.
//

import XCTest
import CryptoKit

import Datable
import SwiftHexTools

@testable import Shadow

class ShadowTests: XCTestCase
{
    /*
     AEAS128
     salt: 0086429422a53772e7a0db444d09a1df59127093d3de30ad
     plaintext: 0001020304
     nonce:  18f89abe0c25def2806ba68a
     key:  c75c1754983aa4ce0c2f8f0707a63210
     subkey base64:  vru391Vs32PEhzOuiS325A==
     subkey hex:  bebbb7f7556cdf63c48733ae892df6e4
     Encrypted Data base64:  I2lhGBsa1w45XV9I486z4A3j7oro
     Encrypted Data Hex:  236961181b1ad70e395d5f48e3ceb3e00de3ee8ae8
     
     AEAS192
     salt24:  6e23d63f4524d9423db499b08d6002c3353996d562609bf0
     aeas24Nonce base64:  9y3YUf37OrbhoESq
     aeas24Nonce hex:  f72dd851fdfb3ab6e1a044aa
     aeas24Key base64:  zxhocnRVToKo5axoM9ZiCRV8ZwU9zRD9
     aeas24Key hex:  cf18687274554e82a8e5ac6833d66209157c67053dcd10fd
     aeas24Subkey base64:  mEl7TEjOwbOBvCpwT9fA6xQuJJ5t8EOC
     aeas24Subkey hex:  98497b4c48cec1b381bc2a704fd7c0eb142e249e6df04382
     Encrypted Data base64:  NJ2FGAA4h35pvqgHqbpqEEwYPmif
     Encrypted data hex:  349d85180038877e69bea807a9ba6a104c183e689f
     
     AEAS256
     salt32:  ad4538dfc44c3072e5487d232cca7d152ac51c7b968f8790c3f76ad574299c9d
     aeas32Nonce base64:  MSX/t7/6kgl56xFP
     aeas32Nonce hex:  3125ffb7bffa920979eb114f
     aeas32Key base64:  aFkrPPcQtd5QLc5xBuUhazfDQijc3HVXb974bqnSH4c=
     aeas32Key hex:  68592b3cf710b5de502dce7106e5216b37c34228dcdc75576fdef86ea9d21f87
     aeas32Subkey base64:  k7qvG929qzyHVF7D2Bxke78qIxk1A8jk/JKSA7K0V40=
     aeas32Subkey hex:  93baaf1bddbdab3c87545ec3d81c647bbf2a23193503c8e4fc929203b2b4578d
     Encrypted Data base64:  6k8tJuPU87yBFrtniSage8SX9xiU
     Encrypted data hex:  ea4f2d26e3d4f3bc8116bb678926a07bc497f71894
     
     ChaChaPoly
     salt32 hex:  ad4538dfc44c3072e5487d232cca7d152ac51c7b968f8790c3f76ad574299c9d
     chachaPolyNonce base64:  kA3DoGigyGYfF2bj
     chachaPolyNonce hex:  900dc3a068a0c8661f1766e3
     chachaPolyKey base64:  q2f5hKCwszOLvvsc4g1cMj1gwho1O3dE2ttwTks8haE=
     chachaPolyKey hex:  ab67f984a0b0b3338bbefb1ce20d5c323d60c21a353b7744dadb704e4b3c85a1
     chachaPolySubkey base64:  mnbqMaGH95dS2jZXaeT9UTszQ0myRcBu1CCjxA+MafY=
     chachaPolySubkey hex:  9a76ea31a187f79752da365769e4fd513b334349b245c06ed420a3c40f8c69f6
     Encrypted data base64:  LJQq3ms5dYIPoN/csclHFuCU1EH0
     Encrypted data hex:  2c942ade6b3975820fa0dfdcb1c94716e094d441f4

     */
    
    let plainText = Data(array: [0, 1, 2, 3, 4])
    
    override func setUp() {
        super.setUp()
        
    }

    // AES.GCM 128
    func testAES128()
    {
        let nonce = Data(base64Encoded: "GPiavgwl3vKAa6aK")
        let key = Data(base64Encoded: "vru391Vs32PEhzOuiS325A==")
        
        // Encrypt a thing
        do
        {
            //Seal
            let encrypted = try AES.GCM.seal(plainText,
                                             using: SymmetricKey(data: key!),
                                             nonce: AES.GCM.Nonce(data: nonce!))
            
            let nonceHex = SwiftHexTools.hexdump(nonce!.array)
            let keyHex = SwiftHexTools.hexdump(key!.array)
            
            let correct = Data(base64Encoded: "I2lhGBsa1w45XV9I486z4A3j7oro")
            let correctHex = SwiftHexTools.hexdump(correct!.array)
            
            let encryptedCombinedHex = SwiftHexTools.hexdump(encrypted.combined!.array)
            let encryptedCipherHex = SwiftHexTools.hexdump(encrypted.ciphertext.array)
            let cipherTagHex = SwiftHexTools.hexdump(encrypted.combined![12...].array)
            
            print("Plaintext hex: \n\(SwiftHexTools.hexdump(plainText.array))")
            print("Key hex: \n\(keyHex)")
            print("Nonce hex: \n\(nonceHex)")
            print("🔒 Encrypted combined hex: \n\(encryptedCombinedHex)")
            print("Encrypted cipher hex: \n\(encryptedCipherHex)")
            print("Correct Hex: \n\(correctHex)")
            print("Encrypted + tag: \n\(cipherTagHex)")
            
            XCTAssertEqual(encrypted.combined![12...], correct)
        }
        catch let error
        {
            print("Error encrypting data: \(error)")
            XCTFail()
        }
    }
    
    // AES.GCM 192
    func testAES192()
    {
        let nonce = Data(base64Encoded: "9y3YUf37OrbhoESq")
        let key = Data(base64Encoded: "mEl7TEjOwbOBvCpwT9fA6xQuJJ5t8EOC")
        
        // Encrypt a thing
        do
        {
            //Seal
            let encrypted = try AES.GCM.seal(plainText,
                                             using: SymmetricKey(data: key!),
                                             nonce: AES.GCM.Nonce(data: nonce!))
            let correct = Data(base64Encoded: "NJ2FGAA4h35pvqgHqbpqEEwYPmif")
            
            XCTAssertEqual(encrypted.combined![12...], correct)
        }
        catch let error
        {
            print("Error encrypting data: \(error)")
            XCTFail()
        }
    }
    
    // AES.GCM 256
    func testAES256()
    {
        let nonce = Data(base64Encoded: "MSX/t7/6kgl56xFP")
        let key = Data(base64Encoded: "k7qvG929qzyHVF7D2Bxke78qIxk1A8jk/JKSA7K0V40=")
        
        // Encrypt a thing
        do
        {
            //Seal
            let encrypted = try AES.GCM.seal(plainText,
                                             using: SymmetricKey(data: key!),
                                             nonce: AES.GCM.Nonce(data: nonce!))
            let correct = Data(base64Encoded: "6k8tJuPU87yBFrtniSage8SX9xiU")
            
            XCTAssertEqual(encrypted.combined![12...], correct)
        }
        catch let error
        {
            print("Error encrypting data: \(error)")
            XCTFail()
        }
    }
    
    // AES.GCM ChaChaPoly
    func testChaChaPoly()
    {
        let nonce = Data(base64Encoded: "kA3DoGigyGYfF2bj")
        let key = Data(base64Encoded: "mnbqMaGH95dS2jZXaeT9UTszQ0myRcBu1CCjxA+MafY=")
        
        do
        {
            let encrypted = try ChaChaPoly.seal(plainText,
                                                using: SymmetricKey(data: key!),
                                                nonce: ChaChaPoly.Nonce(data: nonce!))
            let correct = Data(base64Encoded: "LJQq3ms5dYIPoN/csclHFuCU1EH0")
            XCTAssertEqual(encrypted.combined[12...], correct)
        }
        catch let error
        {
            print("Error encrypting data: \(error)")
            XCTFail()
        }
    }
    
    func shadowHKDF(secret: Data, salt: Data, info: Data) -> Data
    {
        return Data()
    }
    
    func testHKDF()
    {
        let correct = Data()
        let secret = Data()
        let salt = Data()
        let info = Data()
        
        let result = shadowHKDF(secret: secret, salt: salt, info: info)
        
        
        
        XCTAssertEqual(result, correct)
    }
}
