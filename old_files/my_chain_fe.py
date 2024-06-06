from collections import defaultdict
import random
import time



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
        for midi in self.dataset:
            for order in range(1, self.max_order+1):
                for i in range(len(midi) - order):
                    state = tuple(midi[i:i+order])
                    next_state = midi[i+order]
                    self.transitions[state][next_state] += 1

    def generate(self, state, set_order):
        #This for loop tries to generate the new state for the max order set for the generation (set_order)
        #if a tuple has never been encountered in the dataset (i.e. it has no probability outcome) the algorithm
        #lowers the order to be considered increasing the probability to have encountered that tuple.
        #Ultimately if the order reaches 1, the tuple is granted to be previously encountered in the dataset
        #allowing to effectively generate the next state
        for order in range(set_order, 0, -1):
            if state[-order:] in self.transitions:
                choices, weights = zip(*self.transitions[state[-order:]].items())
                if len(choices)>=2 or order==1:
                    next_state = random.choices(choices, weights=weights)[0]
                    print("Max order "+str(self.max_order))
                    print("Set order "+str(set_order))
                    print("Employed order "+str(order))
                    return next_state
        raise ValueError("State not found in the Markov chain")






'''
#INITIALIZE
dataset = [1, 2, 3, 4, 5, 3, 3, 2, 4, 1, 1, 2, 3, 5, 4, 2, 3, 3, 1, 5, 3, 2, 1, 1, 3, 5, 3, 5, 2, 3, 1, 5, 4, 3, 2, 1, 5, 5, 3, 3]
#Max order for which the chain and probability matrix are computed (it will also be computed for all orders lower than the max one)
max_order = 12 
#Max order considered for generating new states (can be dynamically changed by the closeness parameter coming from touchdesigner via osc)
set_order = 8  
markov_chain = VariableLengthMarkovChain(max_order, dataset)
#print(markov_chain.transitions)




#GENERATE
state = tuple(dataset[0:set_order])
for i in range(100):
    next_state = markov_chain.generate(state, set_order)
    print("Next state after", state, ":", next_state)
    #update current state with next state requires the tuple to be converted to list,
    #manipulated and converted back to tuple
    update_state=list(state)
    update_state.pop(0)
    update_state.append(next_state)
    state=tuple(update_state)
    #control generation/printing flow (currentlty every 1 second)
    time.sleep(1)
'''
