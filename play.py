from pathlib import Path
from typing import List
import mido
import pyOSC3
import time
from my_chain import VariableLengthMarkovChain
from threading import Thread
import re


#PARAMETERS------------------------------------------------------------------------------

max_order=8
set_order=1
velocity_quantization=16
time_quantization=64
dur_quantization=64
tempo_modifier=1
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

#Function to map variables from one range to another
def range_map(OldMax, OldMin, NewMax, NewMin, OldValue):
    OldRange = (OldMax - OldMin)  
    NewRange = (NewMax - NewMin)  
    NewValue = (((OldValue - OldMin) * NewRange) / OldRange) + NewMin
    return NewValue

#Function to menage the received OSC message for closeness (set order)
def handle_message(address, tags, data, client_address):
    global set_order
    set_order = data[0]
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
max_velocity_value = max(velocity_values)
for row in notes_int_dur:
    row[1]=round(range_map(max_velocity_value, 0, velocity_quantization, 0, row[1]))

time_values = [row[2] for row in notes_int_dur]
max_time_value = max(time_values)
for row in notes_int_dur:
    row[2]=round(range_map(max_time_value, 0, time_quantization, 0, row[2]))

dur_values = [row[3] for row in notes_int_dur]
max_dur_value = max(dur_values)
min_dur_value = min(dur_values)
for row in notes_int_dur:
    row[3]=round(range_map(max_dur_value, min_dur_value, dur_quantization, 0, row[3]))

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
tempo*=tempo_modifier







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
    next_state_velocity=range_map(velocity_quantization, 0, max_velocity_value, 0, res[1])
    next_state_time=range_map(time_quantization, 0, max_time_value, 0, res[2])
    next_state_dur= mido.tick2second(range_map(dur_quantization, 0, max_dur_value, 50, res[3]), ticks_per_beat, tempo)

    #prepare the message
    msg = pyOSC3.OSCMessage()
    msg.setAddress("/numbers")
    out=[next_state_notes, next_state_velocity, next_state_time, next_state_dur]
    msg.append(out)
    
    #compute the delta time, it's the time that should pass between the last note played and the current note
    delta_time = mido.tick2second(next_state_time, ticks_per_beat, tempo)
    print(delta_time)
    time.sleep(delta_time)

    #print and send
    print(res)
    print("")
    client.send(msg)
