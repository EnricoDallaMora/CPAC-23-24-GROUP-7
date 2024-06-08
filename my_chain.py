from collections import defaultdict
import random



#MARKOV CHAIN CLASS
class VariableLengthMarkovChain:
    def __init__(self, max_order, dataset):
        self.max_order = max_order
        self.dataset = dataset
        #Dictionary inside dictionary: the first key is the current state to which another dictionary is linked.
        #The second dictionary has the possible outcome as key and the probability (integer number) as the linked value.
        self.transitions = defaultdict(lambda: defaultdict(int))
        self._build_transitions()

    def _build_transitions(self):
        #Builds the probability matrix for all orders equal or less than max_order
        for order in range(self.max_order+1):
            for i in range(len(self.dataset) - order):
                state = tuple(self.dataset[i:i+order])
                next_state = self.dataset[i+order]
                self.transitions[state][next_state] += 1

    def generate(self, state, set_order):
        #This for loop tries to generate the new state for the max order set for the generation (set_order)
        #if a tuple has never been encountered in the dataset (i.e. it has no probability outcome) the algorithm
        #lowers the order to be considered increasing the probability to have encountered that tuple.
        #Ultimately if the order reaches 1, the tuple is granted to be previously encountered in the dataset
        #allowing to effectively generate the next state
        if set_order>self.max_order:
            set_order=self.max_order
        if set_order<1:
            set_order=1    
        for order in range(set_order, 0, -1):
            if state[(set_order-order):set_order] in self.transitions:
                choices, weights = zip(*self.transitions[state[(set_order-order):set_order]].items())
                print("Choices "+str(choices)+", weights "+str(weights))
                next_state = random.choices(choices, weights=weights)[0]
                print("Max order "+str(self.max_order))
                print("Set order "+str(set_order))
                print("Employed order "+str(order))
                return next_state
        raise ValueError("State not found in the Markov chain")

