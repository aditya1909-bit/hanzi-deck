# Adaptive Learn

Adaptive Learn is Hanzi Deck's local, personalized study policy. It is intended for decks that feel too large to learn effectively in one pass.

The policy starts with a small working set and learns separately for each deck. Every Again, Hard, Good, or Easy rating updates three things:

- the estimated mastery and uncertainty of that card;
- the number of cards the learner handles well at once, constrained to 4–16;
- how likely each rating is to need another same-session review, and how many cards should appear before that retry.

The next session favors cards with low estimated mastery, overdue cards, relearning cards, and cards for which the app has little evidence. This balances practice of known weak material with exploration of under-tested material. Again cards begin by repeating after three intervening cards, while Hard, Good, and Easy begin with progressively longer or no same-session retries. Those choices change as the app observes the learner's result the next time each card appears.

This is a lightweight contextual-bandit policy, a form of online reinforcement learning. It does not train a neural network, download a model, send study history to a server, or share learning data between users. Conservative defaults make it useful immediately; personalization gradually replaces those defaults as local review evidence accumulates. The normal FSRS-6, SM-2, Leitner, or Simple scheduler still determines long-term due dates.

The design draws on research showing the value of learner-specific memory estimates and online adaptive sequencing:

- [A Trainable Spaced Repetition Model for Language Learning](https://aclanthology.org/P16-1174/)
- [Enhancing human learning via spaced repetition optimization](https://doi.org/10.1073/pnas.1815156116)
- [Multi-Armed Bandits for Intelligent Tutoring Systems](https://doi.org/10.5281/zenodo.3554667)

The policy is intentionally transparent and deterministic apart from tie-breaking and final card shuffling. Its limits and update rules live in `StudySessionBuilder.swift` and `StudySession.cs`, making them straightforward to inspect, test, and improve.
