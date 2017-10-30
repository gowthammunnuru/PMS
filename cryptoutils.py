# DreamWorks Animation LLC Confidential Information.
# TM and (c) 2013 DreamWorks Animation LLC.  All Rights Reserved.
# Reproduction in whole or in part without prior written permission of a
# duly authorized representative is prohibited.

import os
from Crypto.Cipher import AES
from Crypto.Hash import SHA256

salt = 'line'

# Initilization Vector
iv = os.urandom(16)

# Block Size
BS = 32

pad = lambda s: s + (BS - len(s) % BS) * chr(BS - len(s) % BS)
unpad = lambda s: s[0:-ord(s[-1])]

########################
# 1. Create the SHA256 hash from the passphrase. 
#    This is required to ensure key is of fixed length
# 2. Create the Encoder/Decoder Object based on key (from above) and Initialization Vector
#    The IV will ensure that same key and same message *wont* produce the same cipher
# 3. (Encrypt) - Using the Encoder/Decoder Object from step 2
# 4. (Decrupt) - Using the Encode/Decoder Object from step 2
#
########################


def getKeyFromPassphrase(passphrase):
    """
    Creates a SHA256 hash from the input passphrase

    We dont directly use the passphrase as keys because keys need to be of a certain
    byte length, and hash functions are great in creating predictable length strings
    """

    key = SHA256.new()
    key.update(passphrase)

    return key.digest(), key.hexdigest()


def getCryptoObj(passphrase, ivector = iv):
    """
    Creates the Crypto Object based on the key and Intialization Vector
    """
    return AES.new(passphrase, AES.MODE_CBC, iv)


def encrypt(message, passphrase):
    """
    Accepts a plaintext (unencrypted) and a passphrase, and return ciphertext back
    """

    key, _ = getKeyFromPassphrase(passphrase)

    # Create the encoder object based on the passphrase
    encoder = getCryptoObj(key)

    # Encrypt the message
    encrypted = encoder.encrypt(pad(message))

    return encrypted


def decrypt(cipher, passphrase):
    """
    Accepts a cipher (encrypted) and a passpharse, and return plaintext message back
    """

    key, _ = getKeyFromPassphrase(passphrase)

    decoder = getCryptoObj(key)

    message = decoder.decrypt(cipher)

    return unpad(message)
