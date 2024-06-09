from pathlib import Path
from typing import List
import mido
import pyOSC3
import time
from my_chain import VariableLengthMarkovChain
from threading import Thread
import re
import numpy as np
from sklearn.preprocessing import QuantileTransformer
from scipy.stats import norm


#PARAMETERS------------------------------------------------------------------------------

max_order=5
set_order=1
N_vel=8
N_time=8
N_dur=8
spacing=1
tempo_modifier_max=8
tempo_modifier_min=2
dataset_directory=Path("./maestro-v3.0.0/2017")





#SETUP-----------------------------------------------------------------------------------

#Function to encode midi files into strings
def encode(file: mido.MidiFile) -> List[str]:
    notes = []

    for message in mido.merge_tracks(file.tracks):
        if message.type != "note_on":
            continue

        notes.append(str(message))

    return notes

#Function to set the tempo and the bpm of the dataset midi files 
def setup_time(file: mido.MidiFile):
    for message in file:
        if message.type == 'set_tempo':
            tempo = message.tempo
            bpm = mido.tempo2bpm(tempo)
            break

    return tempo, bpm

#Function to quantize values on a set of indexes centered on the peak of a gaussian distribution of the values
def transform_and_quantize(values, N, spacing):
    # Reshape values for QuantileTransformer
    values = np.array(values).reshape(-1, 1)
    
    # Quantile transformation to uniform distribution
    qt = QuantileTransformer(n_quantiles=min(len(values), 100), output_distribution='uniform')
    uniform_values = qt.fit_transform(values)
    
    # Transform uniform distribution to Gaussian distribution
    gaussian_values = norm.ppf(uniform_values)
    
    # Define quantization levels directly over a standard Gaussian range
    quantization_levels = np.linspace(-spacing, spacing, N)
    
    # Quantize the Gaussian-distributed values
    quantized_indices = np.digitize(gaussian_values, quantization_levels, right=True) - 1
    quantized_indices = np.clip(quantized_indices, 0, N-1)
    
    return quantized_indices, qt

#Function to convert back indexes to original values from the gaussian distribution
def inverse_transform(quantized_indices, qt, N, spacing):
    # Define quantization levels directly over a standard Gaussian range
    quantization_levels = np.linspace(-spacing, spacing, N)
    
    # Get the Gaussian values from quantized indices
    gaussian_values = quantization_levels[quantized_indices]
    
    # Transform Gaussian values back to uniform distribution
    uniform_values = norm.cdf(gaussian_values)
    
    # Inverse transform uniform distribution back to original values
    original_values = qt.inverse_transform(uniform_values.reshape(-1, 1))
    
    return original_values.ravel()


#Function to menage the received OSC message for closeness (set order)
def handle_message(address, tags, data, client_address):
    global set_order
    if int(data[0])<1:
        set_order=1
    else:
        set_order = int(data[0])
    print(f"Ricevuto messaggio da {address}: {set_order}")

#Function to run the server in a separated thread
def run_server():
    server = pyOSC3.OSCServer(("127.0.0.1", 57000))
    server.addMsgHandler("/closeness", handle_message)
    print(f"In ascolto")
    # Run the server
    server.serve_forever()








#MIDI PROCESSING-------------------------------------------------------------------------

dataset_notes = []
notes_int=[]
notes_int_dur=[]

#Read midi files, encode and store data in dataset_notes
for filename in dataset_directory.iterdir():
    with mido.MidiFile(filename) as file:
        notes = encode(file)

    dataset_notes.extend(notes)
    print(f"Processed {filename}")    

#Print stuff for control purposes, to be deleated once the code is definitive
with open("Input.txt", "w") as text_file:
    print(f"Note: "+str(dataset_notes), file=text_file)


#Convert midi infos from strings to numbers [dataset_notes->notes_int]
for i in range(len(dataset_notes)):
    temp = re.findall(r'\d+', dataset_notes[i])
    res = list(map(int, temp))
    notes_int.append([res[1], res[2], res[3]])

#Print stuff for control purposes, to be deleated once the code is definitive
with open("Notes_int.txt", "w") as text_file:
    print(f""+str(notes_int), file=text_file)

#Midi information processing: [notes_int->notes_int_dur]
#Extracts the duration (dur) feature by evaluating after how much time the note 
#velocity is set to 0
#Removes 0 velocity messages and adds a 4th parameter: dur
for i in range(len(notes_int)-1):
    if notes_int[i][1]!=0:
        temp=0
        for j in range(i+1, len(notes_int)):
            temp+=notes_int[j][2]
            if notes_int[i][0]==notes_int[j][0] and notes_int[j][1]==0:
                notes_int[i].append(temp)
                notes_int_dur.append(notes_int[i])
                #adds the time interval from the 0 velocity removed message 
                #to previous one in order to keep time consistency
                notes_int[j-1][2]+=notes_int[j][2]
                break
            
#Print stuff for control purposes, to be deleated once the code is definitive
with open("Notes_int_dur.txt", "w") as text_file:
    print(f""+str(notes_int_dur), file=text_file)

#Change the range of values of notes_int_dur for velocity time and dur in order to
#higher the chance of one tuple appearing more than once 
#(i.e. making the generation less deterministic)
velocity_values = [row[1] for row in notes_int_dur]
processed_column, qt_vel = transform_and_quantize(velocity_values, N_vel, spacing)
for i in range(len(notes_int_dur)):
    notes_int_dur[i][1] = processed_column[i]

time_values = [row[2] for row in notes_int_dur]
processed_column, qt_time = transform_and_quantize(time_values, N_time, spacing)
for i in range(len(notes_int_dur)):
    notes_int_dur[i][2] = processed_column[i]

dur_values = [row[3] for row in notes_int_dur]
processed_column, qt_dur = transform_and_quantize(dur_values, N_dur, spacing)
for i in range(len(notes_int_dur)):
    notes_int_dur[i][3] = processed_column[i]

#Print stuff for control purposes, to be deleated once the code is definitive
with open("Notes_int_dur_ranged.txt", "w") as text_file:
    print(f""+str(notes_int_dur), file=text_file)

#Convert back to tuple as to be consistent with the following sections of code
#Overwriting dataset_notes [notes_int_dur->a->dataset_notes]
a=[]
for i in range(len(notes_int_dur)):
    a.append(""+str(notes_int_dur[i][0])+" "+str(notes_int_dur[i][1])+" "+str(notes_int_dur[i][2])+" "+str(notes_int_dur[i][3]))
dataset_notes=a

#Print stuff for control purposes, to be deleated once the code is definitive
with open("dataset_notes.txt", "w") as text_file:
    print(f""+str(a), file=text_file)

#set tempo, bpm and ticks per beat
first_file_midi = next(dataset_directory.iterdir())
with mido.MidiFile(first_file_midi) as file:
    tempo, bpm = setup_time(file)
    ticks_per_beat = file.ticks_per_beat

print(tempo, bpm, ticks_per_beat)








#CHAIN GENERATION----------------------------------------------------------------------

#Chain model and matrix generation
markov_chain_notes = VariableLengthMarkovChain(max_order, dataset_notes)






#NOTES GENERATION----------------------------------------------------------------------

#Receive closeness (set_order) data
server_thread = Thread(target=run_server)
server_thread.start()

#Run client to send generated notes
client = pyOSC3.OSCClient()
client.connect( ( '127.0.0.1', 57120 ) )

#Initialize generation starting tuple from one of the existing files in the dataset
state_notes = tuple(dataset_notes[0:set_order])

#list containing all the generated states from which (line 121) 
#the current state is extracted based on the set_order
all_states=[] 
all_states.extend(list(state_notes))

#initialize output file to blank (file per controllare se le stringhe generate hanno senso)
with open("Output.txt", "w") as text_file:
        print(f"", file=text_file)

#Generation
while True:
    tempo_osc=tempo*(tempo_modifier_max-((set_order-max_order)/(1-max_order))*(tempo_modifier_min-tempo_modifier_max))
    state_notes=tuple(all_states[(len(all_states)-set_order):len(all_states)])
    next_state_notes = markov_chain_notes.generate(state_notes, set_order)
    all_states.append(next_state_notes)

    #Print stuff for control purposes, to be deleated once the code is definitive 
    with open("Output.txt", "a") as text_file:
        print(f"Note: "+str(next_state_notes), file=text_file)
    
    #Print stuff for control purposes, to be deleated once the code is definitive
    with open("state_notes.txt", "a") as text_file:
        print(f"Note: "+str(state_notes), file=text_file)

    #divide string and extract numbers to be sent via OSC
    #values are re-ranged to their original values
    temp = re.findall(r'\d+', next_state_notes)
    res = list(map(int, temp))
    next_state_notes=res[0]
    next_state_velocity = int(inverse_transform(res[1], qt_vel, N_vel, spacing)[0])
    next_state_time = int(inverse_transform(res[2], qt_time, N_time, spacing)[0])
    next_state_dur= mido.tick2second(int(inverse_transform(res[3], qt_dur, N_dur, spacing)[0]), ticks_per_beat, tempo_osc)

    #prepare the message
    msg = pyOSC3.OSCMessage()
    msg.setAddress("/numbers")
    out=[next_state_notes, next_state_velocity, next_state_time, next_state_dur]
    msg.append(out)
    
    #compute the delta time, it's the time that should pass between the last note played and the current note
    delta_time = mido.tick2second(next_state_time, ticks_per_beat, tempo_osc)
    print(delta_time)
    time.sleep(delta_time)

    #print and send
    print(res)
    print("")
    client.send(msg)
