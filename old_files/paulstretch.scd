ServerOptions.inDevices;
Server.default.options.inDevice_("Gruppo microfoni (Realtek(R) Audio");

(
SynthDef(\reverb, {
	arg in = 90,
		processMode = 0, // 0 uses Control values, 1 uses Bus for any param suffix Bus.
		gain = 0, mix = 1,
		processGain = 0, processGainBus = 99,
		preDelay = 0.001, bandwidth = 0.998,
		decayRate = 0.97, decayRateBus = 99,
		tailDensity = 0.7, damping = 0.0005,
		excursionDepth = 0.2, excursionRate = 5,
		shimmerPitch = 4, shimmerPitchBus = 99,
		out = 94;

	// funcs
	var sampleRate		= Server.default.sampleRate;
	var equalPower        = {
		arg mix = 0.5;
		[(1-mix).sqrt, mix.sqrt];
	};
	var sampSec           = {
		arg numSamp, sampRate;
		numSamp / sampRate;
	};

	var gFacT60           = {
		arg delay, gFac;
		gFac.sign * (-3 * delay / log10(gFac.abs));

	};
	// some constant values
	// dSR = datorroSampleRate, sampleRate used in the paper.
	var dSR = 29761;
	var maxExcursion    = 32; // samples

	// values for prep part
	var preTankVals = [
		[0.75, 0.75, 0.625, 0.625], // gFacs
		sampSec.value([142, 107, 379, 277], dSR) // times
	].flop;

	// values for tank part
	// note that Dattorro flipped the sign of gFacs for the decaying APs,
	// I do that here so I don't worry about the signs later.
	var tankAP1GFac = -1 * tailDensity;
	var tankAP1Time = 672;
	var tankDel1    = sampSec.value(4453, dSR);
	var tankAP2GFac = (decayRate + 0.15).min(0.5).max(0.25);
	var tankAP2Time = sampSec.value(1800, dSR);
	var tankDel2    = sampSec.value(3720, dSR);

	var tankAP3GFac = tankAP1GFac;
	var tankAP3Time = 908;
	var tankDel3    = sampSec.value(4217, dSR);
	var tankAP4GFac = tankAP2GFac;
	var tankAP4Time = sampSec.value(2656, dSR);
	var tankDel4    = sampSec.value(3163, dSR);

	// Signals
	var dry     = In.ar(in, 2);
	var preTank = Silent.ar;
	var tank    = Silent.ar;
	var wetL    = Silent.ar;
	var wetR    = Silent.ar;
	var wet     = Silent.ar;
	var outs    = Silent.ar;

	// Params
	var pGain = Select.kr(processMode, [processGain.dbamp, Lag.kr(In.kr(processGainBus), 0.05)]);
	var sPitch = Select.kr(processMode, [shimmerPitch, Lag.kr(In.kr(shimmerPitchBus), 0.05)]);

	var fback;

	var dryAmp, wetAmp;
	#dryAmp, wetAmp = equalPower.value(mix);

	// proper mappings for params
	damping = (damping + (1 + (8 * damping))).log / (10.log); // somewhat better than linear
	bandwidth = 3.pow(bandwidth) - (1 + bandwidth);


	// ROUTINGS
	// make it mono
	preTank = (dry[0] + dry[1]) / 2;
	// pregain
	preTank = preTank * pGain;
	// predelay
	preTank = DelayC.ar(preTank, preDelay, preDelay);
	// lowpass
	preTank = LPF.ar(preTank, sampleRate / 2 * bandwidth);

	// 4 All-passes to diffuse inputs
	preTankVals.do({ arg pair; // 0: gFac, 1: time
		preTank = AllpassC.ar(preTank, pair[1], pair[1], gFacT60.value(pair[1], pair[0]));
	});

	fback = LocalIn.ar(1);

	// // Tank starts here
	// first branch
	tank  = AllpassC.ar(preTank + (decayRate * fback),
		maxdelaytime: sampSec.value(tankAP1Time + maxExcursion, dSR),
		delaytime: sampSec.value(tankAP1Time, dSR)
		+ (sampSec.value(maxExcursion, dSR) * excursionDepth * SinOsc.ar(excursionRate)),
		decaytime: gFacT60.value(sampSec.value(tankAP1Time, dSR), tankAP1GFac)
	);

	     wetL = -0.6 * DelayC.ar(tank, sampSec.value(1990, dSR), sampSec.value(1990, dSR)) + wetL;
	     wetR = 0.6 * tank + wetR;
	     wetR = 0.6 * DelayC.ar(tank, sampSec.value(3300, dSR), sampSec.value(3300, dSR)) + wetR;
	tank = DelayC.ar(tank, tankDel1, tankDel1);
	tank = LPF.ar(tank, sampleRate / 2 * (1 - damping)) * decayRate;
	     wetL = -0.6 * tank + wetL;
	tank = AllpassC.ar(tank, tankAP2Time, tankAP2Time, gFacT60.value(tankAP2Time, tankAP2GFac));
	     wetR = -0.6 * tank + wetR;
	tank = DelayC.ar(tank, tankDel2, tankDel2);
	     wetR = 0.6 * tank + wetR;

	// // second branch
	tank  = AllpassC.ar((tank * decayRate) + preTank,
		maxdelaytime: sampSec.value(tankAP3Time + maxExcursion, dSR),
		delaytime: sampSec.value(tankAP3Time, dSR)
		+ (sampSec.value(maxExcursion, dSR) * excursionDepth * 0.8 * SinOsc.ar(excursionRate * 0.8)),
		decaytime: gFacT60.value(sampSec.value(tankAP3Time, dSR), tankAP3GFac)
	);

	     wetL = 0.6 * tank + wetL;
	     wetL = 0.6 * DelayC.ar(tank, sampSec.value(2700, dSR), sampSec.value(2700, dSR)) + wetL;
	     wetR = -0.6 * DelayC.ar(tank, sampSec.value(2100, dSR), sampSec.value(2100, dSR)) + wetR;
	tank = DelayC.ar(tank, tankDel3, tankDel3);
	tank = LPF.ar(tank, sampleRate / 2 * (1 - damping)) * decayRate;
	tank = AllpassC.ar(tank, tankAP4Time, tankAP4Time, gFacT60.value(tankAP4Time, tankAP4GFac));
	     wetL = -0.6 * tank + wetL;
	     wetR = -0.6 * DelayC.ar(tank, sampSec.value(200, dSR), sampSec.value(200, dSR)) + wetR;

	tank = DelayC.ar(tank, tankDel4, tankDel4);
	     wetL = 0.6 * tank + wetL;

	tank = tank * decayRate;
	// // Sloppy Shimmering
	tank = PitchShift.ar(tank, pitchRatio: sPitch, mul: Select.kr(sPitch > 1, [1, 2.dbamp]));
	// // Tank ends here
	LocalOut.ar(tank);

    wet = [wetL, wetR];
	wet = HPF.ar(wet, 40); // Prevent lows from blowing up.

	outs = (dry * dryAmp) + (wet * wetAmp);
	outs = outs * gain.dbamp;

	Out.ar(out, outs);
}).add;


SynthDef(\paulstretchMono, { |out = 0, bufnum, envBufnum, pan = 0, stretch = 50000, window = 0.5, rate1=0.5, rate2=1.7, rate3=1, rate4=1.5, ampf1=0.1, ampf2=0.09, ampf3=0.8, ampf4=0.7, amp=0.8, gate=0.0|
	// Paulstretch for SuperCollider
	// Based on the Paul's Extreme Sound Stretch algorithm by Nasca Octavian PAUL
	// https://github.com/paulnasca/paulstretch_python/blob/master/paulstretch_steps.png
	var trigPeriod, sig, chain, trig, pos, fftSize, amp1, amp2, amp3, amp4;
	//amp1=SinOsc.kr(ampf1, 0, 1, 1);
	//amp2=SinOsc.kr(ampf2, 0, 0.15, 0.15);
	//amp3=SinOsc.kr(ampf3, 0, 1, 1);
	//amp4=SinOsc.kr(ampf4, 0, 0.2, 0.2);
	amp1=Env([0, 1, 0], [8, 12], [-1, 2]);
	amp2=Env([0, 0.7, 0], [6, 14], [-1, 2]);
	amp3=Env([0, 0.5, 0], [6, 14], [-1, 2]);
	amp4=Env([0, 0.3, 0], [6, 14], [-1, 2]);
	// Calculating fft buffer size according to suggested window size
	fftSize = 2**floor(log2(window*SampleRate.ir));
	// Grain parameters
	// The grain is the exact length of the FFT window
	trigPeriod = fftSize/SampleRate.ir;
	trig = Impulse.ar(1/trigPeriod);
	pos = Demand.ar(trig, 0, demandUGens: Dseries(0, trigPeriod/stretch));
	// Extraction of 2 consecutive grains
	// Both grains need to be treated together for superposition afterwards
	sig = [(GrainBuf.ar(1, trig, trigPeriod, bufnum, rate1, pos, envbufnum: envBufnum)*EnvGen.kr(amp1, gate: gate))+(GrainBuf.ar(1, trig, trigPeriod, bufnum, rate2, pos, envbufnum: envBufnum)*EnvGen.kr(amp2, gate: gate)),
		(GrainBuf.ar(1, trig, trigPeriod, bufnum, rate3, pos + (trigPeriod/(2*stretch)), envbufnum: envBufnum)*EnvGen.kr(amp3, gate: gate))+(GrainBuf.ar(1, trig, trigPeriod, bufnum, rate4, pos + (trigPeriod/(2*stretch)), envbufnum: envBufnum)*EnvGen.kr(amp4, gate: gate))]*amp;
	// FFT magic
	sig = sig.collect({ |item, i|
		chain = FFT(LocalBuf(fftSize), item, hop: 1.0, wintype: -1);
		// PV_Diffuser is only active if its trigger is 1
		// And it needs to be reset for each grain to get the smooth envelope
		chain = PV_Diffuser(chain, 1 - trig);
		item = IFFT(chain, wintype: -1);
	});
	// Reapply the grain envelope because the FFT phase randomization removes it
	sig = sig*PlayBuf.ar(1, envBufnum, 1/(trigPeriod), loop:1);
	// Delay second grain by half a grain length for superposition
	sig[1] = DelayC.ar(sig[1], trigPeriod/2, trigPeriod/2);
	// Panned output
	Out.ar(90, (GrainBuf.ar(1, trig, trigPeriod, bufnum, rate4, pos + (trigPeriod/(2*stretch)), envbufnum: envBufnum)*EnvGen.kr(amp4, gate: gate)));
	Out.ar(98, Pan2.ar(Mix.new(sig), pan));
}).add;




SynthDef(\clean, {
	arg amp=1, freq=100;
	var in;
	in=In.ar(98, 2);
	in=FreeVerb2.ar(in[0], in[1], 1, 1, 0.8);
	in=HPF.ar(in, freq: 300.0);
	in=LPF.ar(in, freq: freq);
	Out.ar(0, in*amp);
}).add;

SynthDef(\shimmerwet, {
	arg amp=1, cutoff=1200;
	var in;
	in=In.ar(94, 2);
	3.do{in=in.distort;
	in=FreeVerb2.ar(in[0], in[1], 0.93, 1, 0.8);
	in=HPF.ar(in, freq: 1500.0);
	in=LPF.ar(in, freq: cutoff);};
	Out.ar(0, in*amp);
}).add;

a=Synth.new(\clean);
y=Synth.new(\shimmerwet);
z=Synth.new(\reverb);

{
	var envBuf, envSignal, buffer;
	buffer = Buffer.readChannel(s, "C:/Users/enric/Desktop/Samples/string1.wav");
	// The grain envelope
	envBuf = Buffer.alloc(s, s.sampleRate, 1);
	envSignal = Signal.newClear(s.sampleRate).waveFill({|x| (1 - x.pow(2)).pow(1)}, -1.0, 1.0);
	envBuf.loadCollection(envSignal);
	s.sync();
	// Runs indefinitely
	x=Synth(\paulstretchMono, [\bufnum, buffer.bufnum, \envBufnum, envBuf.bufnum]);
}.fork;


OSCdef.new(\0,
	{
		arg msg;
		postln(msg);
		x.set(\rate1, 2**((msg[1]-52)/12));
		x.set(\gate, 1.0);
		{x.set(\gate, 0.0)}.defer(0.1);
		{BPF.ar(WhiteNoise.ar, [msg[1], msg[1]+7].midicps, 1e-5, Env.sine(20).kr(2)).sum!2 * 100}.play;
	},
	'/0',
	nil,
	7001
);
OSCdef.new(\1,
	{
		arg msg;
		postln(msg);
		x.set(\rate2, 2**((msg[1]-52)/12));
		{BPF.ar(WhiteNoise.ar, [msg[1], msg[1]+7].midicps, 1e-5, Env.sine(20).kr(2)).sum!2 * 100}.play;
	},
	'/1',
	nil,
	7001
);
OSCdef.new(\2,
	{
		arg msg;
		postln(msg);
		x.set(\rate3, 2**((msg[1]-52)/12));
		{BPF.ar(WhiteNoise.ar, [msg[1], msg[1]+7].midicps, 1e-5, Env.sine(20).kr(2)).sum!2 * 80}.play;
	},
	'/2',
	nil,
	7001
);
OSCdef.new(\3,
	{
		arg msg;
		postln(msg);
		x.set(\rate4, 2**((msg[1]-52)/12));
		{BPF.ar(WhiteNoise.ar, [msg[1], msg[1]+7].midicps, 1e-5, Env.sine(20).kr(2)).sum!2 * 70}.play;
	},
	'/3',
	nil,
	7001
);
OSCdef.new(\close,
	{
		arg msg;
		postln(msg);
		y.set(\amp, msg[1]*1.5);
		a.set(\freq, LinLin.kr(msg[1], 0, 1, 100, 800));
	},
	'/close',
	nil,
	7002
);
)

a.set(\amp, 0);
a.set(\freq, 500);
y.set(\amp, 1);
y.set(\cutoff, 1000);



//z.set(\shimmerPitch, 2);
//z.set(\shimmerPitch, 1);
//z.set(\gain, 0);
//z.set(\decayRate, 0.97);
//z.set(\damping, 0.00000005);
//z.set(\excursionRate, 5);
//z.set(\bandwidth, 0.998);
//z.set(\mix, 0.7);
//x.set(\stretch, 2);
/*
		processMode = 0, // 0 uses Control values, 1 uses Bus for any param suffix Bus.
		gain = 0, mix = 0.35,
		processGain = 0, processGainBus = 99,
		preDelay = 0.001, bandwidth = 0.998,
		decayRate = 0.9, decayRateBus = 99,
		tailDensity = 0.7, damping = 0.0005,
		excursionDepth = 0.2, excursionRate = 2,
		shimmerPitch = 2, shimmerPitchBus = 99,
		out = 0;
*/

/*
x.set(\rate1, 0.5); //0.5 0.56 0.65 0.67 0.75 0.85 0.9
x.set(\rate1, 0.56);
x.set(\rate1, 0.65);
x.set(\rate1, 0.67);
x.set(\rate1, 0.75);
x.set(\rate1, 0.85);
x.set(\rate1, 0.9);
x.set(\rate1, 4);
x.set(\amp, 0);
x.free
//subtractive synthesis
{BPF.ar(WhiteNoise.ar, [76, 80].midicps, 1e-5, Env.sine(10).kr(2)).sum!2 * 50}.play;


{EnvGen.kr(Env([0, 2, 0], [0.5, 0.5]), Impulse.kr(1))}.plot(5);
Env.new([0.01, 2, 0.01], [3, 7], [-3, 4]).plot
Env.new([0, 1, 0], [8, 12], [-1, 2]).plot
{Env.sine(2).kr(0.1)}.plot(5)

//thisProcess.platform.recordingsDir

(
~b3 = Buffer.readChannel(s, thisProcess.nowExecutingPath.dirname +/+ "Voice.mp3", channels: 0);

// audio
SynthDef.new("rat", {
	arg out = 0, tFreq =15, dur = 0.1, rate = 1, pos = 0.8;
	var sig, env, attack=0, decay=1, ratio;


	ratio=Impulse.ar(tFreq);




	//env =  EnvGen.ar(Env([0, 1, 0], [attack, decay], curve: 0), Impulse.kr(1/(attack+decay)));

	sig=GrainBuf.ar(
		numChannels: 2,
		trigger: ratio,
		dur: dur,
		sndbuf: ~b3,
		rate: rate,
		//pos: (pos+LFSaw.ar(10*1/BufDur.ir(~b3)).range(0, (BufSamples.ir(~b3)-1)/10)),
		pos: 0.8-LFSaw.ar(1/(10*BufDur.ir(~b3))),
		//pos: pos,
		interp: 2,
		pan: 0,
		envbufnum: -1,
		maxGrains: 512);

	//sig = sig*env;
	Out.ar(99, FreeVerb.ar(sig, 0, 1, 0.1, 10, 0));

}).add;

y = Synth.new(\rat);
)

y.free

*/