import pyOSC3
import time, random
import numpy as np
import pandas as pd
from collections import Counter
from array import *
import schedule


errors = {
    'program': 'Bad input, please refer this spec-\n'
               'http://www.electronics.dit.ie/staff/tscarff/Music_technology/midi/program_change.htm',
    'notes': 'Bad input, please refer this spec-\n'
             'http://www.electronics.dit.ie/staff/tscarff/Music_technology/midi/midi_note_numbers_for_octaves.htm'
}

####################### OSC

client = pyOSC3.OSCClient()
client.connect( ( '127.0.0.1', 7001 ) )

####################### MARKOV CHAIN 

# read file
data = pd.read_csv('Liverpool_band_chord_sequence.csv')

n = 2
chords = data['chords'].values
ngrams = zip(*[chords[i:] for i in range(n)])
bigrams = [" ".join(ngram) for ngram in ngrams]

bigrams[:5]

def predict_next_state(chord:str, data:list=bigrams):
    """Predict next chord based on current state."""
    # create list of bigrams which stats with current chord
    bigrams_with_current_chord = [bigram for bigram in bigrams if bigram.split(' ')[0]==chord]
    # count appearance of each bigram
    count_appearance = dict(Counter(bigrams_with_current_chord))
    # convert apperance into probabilities
    for ngram in count_appearance.keys():
        count_appearance[ngram] = count_appearance[ngram]/len(bigrams_with_current_chord)
    # create list of possible options for the next chord
    options = [key.split(' ')[1] for key in count_appearance.keys()]
    # create  list of probability distribution
    probabilities = list(count_appearance.values())
    # return random prediction
    return np.random.choice(options, p=probabilities)

def generate_sequence(chord:str=None, data:list=bigrams, length:int=1):
    """Generate sequence of defined length."""
    # create list to store future chords
    chords = []
    for n in range(length):
        # append next chord for the list
        chords.append(predict_next_state(chord, bigrams))
        # use last chord in sequence to predict next chord
        chord = chords[-1]
    return chords

####################### CHORD -> MIDI_NOTE_NUMBER CONVERSION
NOTES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'Bb', 'B']
OCTAVES = list(range(11))
NOTES_IN_OCTAVE = len(NOTES)

def note_to_number(note: str, octave: int) -> int:
    assert note in NOTES, errors['notes']
    assert octave in OCTAVES, errors['notes']

    note = NOTES.index(note)
    note += (NOTES_IN_OCTAVE * (octave+1))

    assert 0 <= note <= 127, errors['notes']

    return note

#################### VOICINGS

major=[0, 7, 16, 24]
minor=[0, 7, 15, 24]
major7=[0, 10, 16, 19]
minor7=[0, 10, 15, 19]
minor6=[0, 9, 15, 19]
sus4=[0, 7, 12, 17]
sev_sus4=[0, 7, 10, 17]
a=['C']


##############################################################################################################################
def sched():
    global a
    ###### GENERATE SEQUENCE

    a=generate_sequence(a[len(a)-1])
    print(a)

    ###### CONVERT CHORD -> MIDI NOTES
    tonic=[]
    chordtype=[]
    tonic_number=[]
    chord_notes = [[0 for i in range(len(major))] for j in range(len(a))]
    chordtypevoicing = [[0 for i in range(len(major))] for j in range(len(a))]


    for i in range (0, len(a)):
        if len(a[i])==1:
            chordtype.append('MAJOR')
            chordtypevoicing[i]=major
            tonic.append(a[i])
        if len(a[i])==2:
            if a[i][1]=='b':
                chordtype.append('MAJOR')
                chordtypevoicing[i]=major
                tonic.append(a[i][0:2])
            if a[i][1]=='m':
                chordtype.append('MINOR')
                chordtypevoicing[i]=minor
                tonic.append(a[i][0])
            if a[i][1]=='7':
                chordtype.append('MAJOR7')
                chordtypevoicing[i]=major7
                tonic.append(a[i][0])
        if len(a[i])==3:
            if a[i][1]=='b':
                tonic.append(a[i][0:2])
                if a[i][2]=='m':
                    chordtype.append('MINOR')
                    chordtypevoicing[i]=minor
                if a[i][2]=='7':
                    chordtype.append('MAJOR7')
                    chordtypevoicing[i]=major7
            if a[i][2]=='7':
                tonic.append(a[i][0])
                chordtype.append('MINOR7')
                chordtypevoicing[i]=minor7
            if a[i][2]=='6':
                tonic.append(a[i][0])
                chordtype.append('MINOR6')
                chordtypevoicing[i]=minor6
        if len(a[i])==4:
            tonic.append([i][0:2])
            chordtype.append('MINOR7')
            chordtypevoicing[i]=minor7
        if len(a[i])==5:
            tonic.append(a[i][0])
            chordtype.append('SUS4')
            chordtypevoicing[i]=sus4
        if len(a[i])==6:
            if a[i][1]=='7':
                tonic.append(a[i][0])
                chordtype.append('7SUS4')
                chordtypevoicing[i]=sev_sus4
            else:
                tonic.append(a[i][0:2])
                chordtype.append('SUS4')
                chordtypevoicing[i]=sev_sus4
        if len(a[i])==7:
            tonic.append(a[i][0:2])
            chordtype.append('7SUS4')
            chordtypevoicing[i]=sev_sus4
        tonic_number.append(note_to_number(tonic[i], 2))
    
        for j in range(0, len(major)):
            chord_notes[i][j]=(tonic_number[i]+chordtypevoicing[i][j])



    print("tonic="+tonic[0])
    print("chord="+chordtype[0])
    print("tonic number="+str(tonic_number[0]))
    print("voicing="+str(chordtypevoicing[0]))
    print("notes="+str(chord_notes[0])+"\n \n")

    ####################### OSC

    for i in range (0, len(a)):
        msg = pyOSC3.OSCMessage()
        msg.setAddress("/0")
        msg.append(chord_notes[i][0])
        client.send(msg)

        msg1 = pyOSC3.OSCMessage()
        msg1.setAddress("/1")
        msg1.append(chord_notes[i][1])
        client.send(msg1)

        msg2 = pyOSC3.OSCMessage()
        msg2.setAddress("/2")
        msg2.append(chord_notes[i][2])
        client.send(msg2)

        msg3 = pyOSC3.OSCMessage()
        msg3.setAddress("/3")
        msg3.append(chord_notes[i][3])
        client.send(msg3)



x=20
while True:
    sched()
    time.sleep(x)
