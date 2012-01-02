module Network.Mail.SMTP.Auth
where

import Data.Digest.MD5
import Codec.Utils
import qualified Codec.Binary.Base64.String as B64 (encode, decode)

import Data.List
import Data.Bits
import Data.Array

type UserName = String
type Password = String

data AuthType = PLAIN
              | LOGIN
              | CRAM_MD5
                deriving Eq

instance Show AuthType where
    showsPrec d at = showParen (d>app_prec) $ showString $ showMain at
        where app_prec = 10
              showMain PLAIN    = "PLAIN"
              showMain LOGIN    = "LOGIN"
              showMain CRAM_MD5 = "CRAM-MD5"

b64Encode :: String -> String
b64Encode = map (toEnum.fromEnum) . B64.encode . map (toEnum.fromEnum)

b64Decode :: String -> String
b64Decode = map (toEnum.fromEnum) . B64.decode . map (toEnum.fromEnum)

showOctet :: [Octet] -> String
showOctet = concat . map hexChars
    where hexChars c = [arr ! (c `div` 16), arr ! (c `mod` 16)]
          arr = listArray (0, 15) "0123456789abcdef"

hmacMD5 :: String -> String -> [Octet]
hmacMD5 text key = hash $ okey ++ hash (ikey ++ map (toEnum.fromEnum) text)
    where koc = map (toEnum.fromEnum) key
          key' = if length koc > 64
                 then hash koc ++ replicate 48 0
                 else koc ++ replicate (64-length koc) 0
          ipad = replicate 64 0x36
          opad = replicate 64 0x5c
          ikey = zipWith xor key' ipad
          okey = zipWith xor key' opad

plain :: UserName -> Password -> String
plain user pass = b64Encode $ concat $ intersperse "\0" [user, user, pass]

login :: UserName -> Password -> (String, String)
login user pass = (b64Encode user, b64Encode pass)

cramMD5 :: String -> UserName -> Password -> String
cramMD5 challenge user pass =
    b64Encode (user ++ " " ++ showOctet (hmacMD5 challenge pass))

auth :: AuthType -> String -> UserName -> Password -> String
auth PLAIN    _ u p = plain u p
auth LOGIN    _ u p = let (u', p') = login u p in unwords [u', p']
auth CRAM_MD5 c u p = cramMD5 c u p
