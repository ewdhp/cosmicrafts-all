import random
from datetime import datetime

class User:
    def __init__(self, name):
        self.name = name

class Match:
    def __init__(self, user1, user2):
        self.user1 = user1
        self.user2 = user2
        self.winner = None
        self.summary = ""

    def simulate(self):
        self.winner = random.choice([self.user1, self.user2])
        self.summary = f"{self.user1.name} vs {self.user2.name} - Winner: {self.winner.name}"

class Tournament:
    def __init__(self, name, start_date, prize_pool, expiration_date):
        self.name = name
        self.start_date = start_date
        self.prize_pool = prize_pool
        self.expiration_date = expiration_date
        self.users = []
        self.matches = []

    def add_user(self, user):
        self.users.append(user)

    def create_bracket(self):
        random.shuffle(self.users)
        for i in range(0, len(self.users), 2):
            if i + 1 < len(self.users):
                match = Match(self.users[i], self.users[i + 1])
                self.matches.append(match)

    def simulate_matches(self):
        for match in self.matches:
            match.simulate()

    def get_summary(self):
        summary = f"Tournament: {self.name}\n"
        summary += f"Start Date: {self.start_date}\n"
        summary += f"Prize Pool: {self.prize_pool}\n"
        summary += f"Expiration Date: {self.expiration_date}\n"
        summary += "Match Results:\n"
        for match in self.matches:
            summary += match.summary + "\n"
        return summary

# Example usage
if __name__ == "__main__":
    tournament = Tournament("Championship", datetime.now(), "1000 USD", datetime(2023, 12, 31))
    
    users = [User(f"User{i}") for i in range(1, 9)]
    for user in users:
        tournament.add_user(user)
    
    tournament.create_bracket()
    tournament.simulate_matches()
    
    print(tournament.get_summary())