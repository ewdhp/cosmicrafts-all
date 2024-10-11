# List of common Spanish phonemes
import random


spanish_phonemes = ['a', 's', 'e', 't', 's', 'ir', 'h', 'e', 't']


def generate_random_username(length=5):
    username = ''
    while len(username) < length:
        phoneme = random.choice(spanish_phonemes)
        if len(username) + len(phoneme) <= length:
            username += phoneme
    return username

# Example usage
print(generate_random_username())