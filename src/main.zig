const std = @import("std");
const Buffer = std.ArrayList;

const Config = struct {
	screen_width: u64,
	screen_height: u64,
	cores: u64,
	mem_size: u64,
	mem: std.mem.Allocator
};

const Register = enum {
	R0=0,
	R1,
	R2,
	R3,
	IP,
	SR,
	SP,
	FP
};

const Core = struct {
	reg: [8]u64,

	pub fn init() Core {
		var core = Core{
			.reg=undefined
		};
		for (0..8) |i| {
			core.reg[i] = 0;
		}
		return core;
	}
};

const Memory = struct {
	mem: []u8,
	words: []align(1) u64,
	half_words: []align(1) u32,

	pub fn init(config: Config) Memory{
		var mem = Memory{
			.mem = config.mem.alloc(u8, config.mem_size) catch unreachable,
			.words = undefined,
			.half_words = undefined,
		};
		mem.words = std.mem.bytesAsSlice(u64, mem.mem[0..]);
		mem.half_words = std.mem.bytesAsSlice(u32, mem.mem[0..]);
		return mem;
	}
};

const Operation = *const fn (*VM, *Core, *align(1) u64) bool;

const VM = struct {
	cores: []Core,
	memory: Memory,

	pub fn init(config: Config) VM {
		var vm = VM{
			.cores = config.mem.alloc(Core, config.cores) catch unreachable,
			.memory = Memory.init(config)
		};
		for (0..config.cores) |i| {
			vm.cores[i] = Core.init();
		}
		return vm;
	}

	pub fn load_bytes(vm: *VM, address: u64, bytes: []u8) bool {
		var i: u64 = address;
		for (bytes) |bytes| {
			vm.memory.mem[i] = byte;
			i += 1;
		}
	}

	pub fn interpret(vm: *VM, core: u64, start: u64) bool {
		vm.cores[core].reg[IP] = start;
		vm.cores[core].reg[SP] = memory.mem.len;
		var running = true;
		var ip = &vm.cores[core].reg[IP];
		const core = &vm.cores[core];
		const ops: [84]Operation = .{
			mov_rr, mov_rl, mov_rdr, 
			mov_drr, mov_drl, mov_drdr,
			add_rrr, add_rrl, add_rlr, add_rll,
			mul_rrr, mul_rrl, mul_rlr, mul_rll,
			sub_rrr, sub_rrl, sub_rlr, sub_rll,
			div_rrr, div_rrl, div_rlr, div_rll,
			mod_rrr, mod_rrl, mod_rlr, mod_rll,
			uadd_rrr, uadd_rrl, uadd_rlr, uadd_rll,
			umul_rrr, umul_rrl, umul_rlr, umul_rll,
			usub_rrr, usub_rrl, usub_rlr, usub_rll,
			udiv_rrr, udiv_rrl, udiv_rlr, udiv_rll,
			umod_rrr, umod_rrl, umod_rlr, umod_rll,
			shr_rrr, shr_rrl, shr_rlr, shr_rll,
			shl_rrr, shl_rrl, shl_rlr, shl_rll,
			and_rrr, and_rrl, and_rlr, and_rll,
			or_rrr, or_rrl, or_rlr, or_rll,
			xor_rrr, xor_rrl, xor_rlr, xor_rll,
			not_rr, not_rl,
			com_rr, com_rl,
			cmp_rr, cmp_rl,
			jmp, jeq, jle, jgt, jge, jlt, jle,
			call, ret_r, ret_l,
			psh_r, pop_r,
			int
		};
		while (running){
			running = ops[vm.memory.half_words[ip.*]&0xFF](vm, core, ip);
		}
	}
};

pub fn mov_rr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x00FF0000) >> 0x10;
	const src = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[src];
	ip.* += 1;
	return true;
}

pub fn mov_rl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const reg = (inst & 0xFF00) >> 0x8;
	const lit = (inst & 0xFFFF0000) >> 0x10;
	core.reg[reg] = lit;
	ip.* += 1;
	return true;
}

pub fn mov_rdr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x00FF0000) >> 0x10;
	const src = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = vm.memory.words[core.reg[src]];
	ip.* += 1;
	return true;
}

pub fn mov_drr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x00FF0000) >> 0x10;
	const src = (inst & 0xFF000000) >> 0x18;
	vm.memory.words[core.reg[dst]] = core.reg[src];
	ip.* += 1;
	return true;
}

pub fn mov_drl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const reg = (inst & 0xFF00) >> 0x8;
	const lit = (inst & 0xFFFF0000) >> 0x10;
	vm.memory.words[core.reg[reg]] = lit;
	ip.* += 1;
	return true;
}

pub fn mov_drdr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x00FF0000) >> 0x10;
	const src = (inst & 0xFF000000) >> 0x18;
	vm.memory.words[core.reg[dst]] = vm.memory.words[core.reg[src]];
	ip.* += 1;
	return true;
}

pub fn add_rrr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] + core.reg[right];
	ip.* += 1;
	return true;
}

pub fn add_rrl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] + right;
	ip.* += 1;
	return true;
}

pub fn add_rlr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = left + core.reg[right];
	ip.* += 1;
	return true;
}

pub fn sub_rrr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] - core.reg[right];
	ip.* += 1;
	return true;
}

pub fn sub_rrl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] - right;
	ip.* += 1;
	return true;
}

pub fn sub_rlr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = left - core.reg[right];
	ip.* += 1;
	return true;
}

pub fn mul_rrr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] * core.reg[right];
	ip.* += 1;
	return true;
}

pub fn mul_rrl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] * right;
	ip.* += 1;
	return true;
}

pub fn mul_rlr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = left * core.reg[right];
	ip.* += 1;
	return true;
}

pub fn div_rrr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] / core.reg[right];
	ip.* += 1;
	return true;
}

pub fn div_rrl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] / right;
	ip.* += 1;
	return true;
}

pub fn div_rlr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = left / core.reg[right];
	ip.* += 1;
	return true;
}

pub fn mod_rrr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] % core.reg[right];
	ip.* += 1;
	return true;
}

pub fn mod_rrl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] % right;
	ip.* += 1;
	return true;
}

pub fn mod_rlr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = left % core.reg[right];
	ip.* += 1;
	return true;
}

pub fn uadd_rrr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] + core.reg[right];
	ip.* += 1;
	return true;
}

pub fn uadd_rrl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] + right;
	ip.* += 1;
	return true;
}

pub fn uadd_rlr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = left + core.reg[right];
	ip.* += 1;
	return true;
}

pub fn usub_rrr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] - core.reg[right];
	ip.* += 1;
	return true;
}

pub fn usub_rrl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] - right;
	ip.* += 1;
	return true;
}

pub fn usub_rlr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = left - core.reg[right];
	ip.* += 1;
	return true;
}

pub fn umul_rrr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] * core.reg[right];
	ip.* += 1;
	return true;
}

pub fn umul_rrl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] * right;
	ip.* += 1;
	return true;
}

pub fn umul_rlr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = left * core.reg[right];
	ip.* += 1;
	return true;
}

pub fn udiv_rrr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] / core.reg[right];
	ip.* += 1;
	return true;
}

pub fn udiv_rrl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] / right;
	ip.* += 1;
	return true;
}

pub fn udiv_rlr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = left / core.reg[right];
	ip.* += 1;
	return true;
}

pub fn umod_rrr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] % core.reg[right];
	ip.* += 1;
	return true;
}

pub fn umod_rrl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] % right;
	ip.* += 1;
	return true;
}

pub fn umod_rlr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = left % core.reg[right];
	ip.* += 1;
	return true;
}

pub fn shr_rrr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] >> core.reg[right];
	ip.* += 1;
	return true;
}

pub fn shr_rrl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] >> right;
	ip.* += 1;
	return true;
}

pub fn shr_rlr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = left >> core.reg[right];
	ip.* += 1;
	return true;
}

pub fn shl_rrr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] << core.reg[right];
	ip.* += 1;
	return true;
}

pub fn shl_rrl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] << right;
	ip.* += 1;
	return true;
}

pub fn shl_rlr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = left << core.reg[right];
	ip.* += 1;
	return true;
}

pub fn and_rrr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] & core.reg[right];
	ip.* += 1;
	return true;
}

pub fn and_rrl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] & right;
	ip.* += 1;
	return true;
}

pub fn and_rlr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = left & core.reg[right];
	ip.* += 1;
	return true;
}

pub fn xor_rrr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] ^ core.reg[right];
	ip.* += 1;
	return true;
}

pub fn xor_rrl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] ^ right;
	ip.* += 1;
	return true;
}

pub fn xor_rlr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = left ^ core.reg[right];
	ip.* += 1;
	return true;
}

pub fn or_rrr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] | core.reg[right];
	ip.* += 1;
	return true;
}

pub fn or_rrl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = core.reg[left] | right;
	ip.* += 1;
	return true;
}

pub fn or_rlr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x0000FF00) >> 0x8;
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = left | core.reg[right];
	ip.* += 1;
	return true;
}

pub fn not_rr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x00FF0000) >> 0x10;
	const src = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = !core.reg[src];
	ip.* += 1;
	return true;
}

pub fn not_rl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x00FF0000) >> 0x10;
	const src = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = !src;
	ip.* += 1;
	return true;
}

pub fn com_rr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x00FF0000) >> 0x10;
	const src = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = ~core.reg[src];
	ip.* += 1;
	return true;
}

pub fn com_rl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const dst = (inst & 0x00FF0000) >> 0x10;
	const src = (inst & 0xFF000000) >> 0x18;
	core.reg[dst] = ~src;
	ip.* += 1;
	return true;
}

pub fn cmp_rr(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	if (vm.core[left] < vm.core[right]){
		core.reg[SR] = 1;
	}
	else if (vm.core[left] > vm.core[right]){
		core.reg[SR] = 2;
	}
	else{
		core.reg[SR] = 0;
	}
	ip.* += 1;
	return true;
}

pub fn cmp_rl(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const left = (inst & 0x00FF0000) >> 0x10;
	const right = (inst & 0xFF000000) >> 0x18;
	if (vm.core[left] < right){
		core.reg[SR] = 1;
	}
	else if (vm.core[left] > right){
		core.reg[SR] = 2;
	}
	else{
		core.reg[SR] = 0;
	}
	ip.* += 1;
	return true;
}

pub fn jmp(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const off = (inst & 0xFFFF0000) >> 0x10;
	core.reg[IP] += off;
	return true;
}

pub fn jeq(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const off = (inst & 0xFFFF0000) >> 0x10;
	if (core.reg[SR] == 0){
		ip* += off;
		return true;
	}
	ip.* += 1;
	return true;
}

pub fn jne(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const off = (inst & 0xFFFF0000) >> 0x10;
	if (core.reg[SR] != 0){
		ip* += off;
		return true;
	}
	ip.* += 1;
	return true;
}

pub fn jlt(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const off = (inst & 0xFFFF0000) >> 0x10;
	if (core.reg[SR] == 1){
		ip* += off;
		return true;
	}
	ip.* += 1;
	return true;
}

pub fn jle(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const off = (inst & 0xFFFF0000) >> 0x10;
	if (core.reg[SR] < 2){
		ip* += off;
		return true;
	}
	ip.* += 1;
	return true;
}

pub fn jgt(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const off = (inst & 0xFFFF0000) >> 0x10;
	if (core.reg[SR] == 2){
		ip* += off;
		return true;
	}
	ip.* += 1;
	return true;
}

pub fn jge(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const off = (inst & 0xFFFF0000) >> 0x10;
	if (core.reg[SR] > 1){
		ip* += off;
		return true;
	}
	ip.* += 1;
	return true;
}

pub fn call(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const off = (inst & 0xFFFF0000) >> 0x10;
	core.reg[SP] -= 8;
	vm.memory.words[core.reg[SP] >> 3] = core.reg[IP]+1;
	core.reg[SP] -= 8;
	vm.memory.words[core.reg[SP] >> 3] = core.reg[FP];
	core.reg[FP] = core.reg[SP];
	core.reg[IP] += off;
	return true;
}

pub fn ret_r(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const reg = (inst & 0xFF00) >> 0x8;
	core.reg[SP] = core.reg[FP];
	core.reg[FP] = vm.memory.words[core.reg[SP] >> 3];
	core.reg[SP] += 8;
	core.reg[IP] = vm.memory.words[core.reg[SP] >> 3];
	vm.memory.words[core.reg[SP] >> 3] = core.reg[reg];
	return true;
}

pub fn ret_l(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const lit = (inst & 0xFF00) >> 0x8;
	core.reg[SP] = core.reg[FP];
	core.reg[FP] = vm.memory.words[core.reg[SP] >> 3];
	core.reg[SP] += 8;
	core.reg[IP] = vm.memory.words[core.reg[SP] >> 3];
	vm.memory.words[core.reg[SP] >> 3] = lit;
	return true;
}

pub fn psh_r(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const reg = (inst & 0xFF00) >> 0x8;
	core.reg[SP] = core.reg[FP];
	core.reg[SP] -= 8;
	vm.memory.words[core.reg[SP] >> 3] = core.reg[reg];
	ip.* += 1;
	return true;
}

pub fn pop_r(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	const inst = vm.memory.half_words[ip];
	const reg = (inst & 0xFF00) >> 0x8;
	core.reg[SP] = core.reg[FP];
	core.reg[reg] = vm.memory.words[core.reg[SP] >> 3];
	core.reg[SP] += 8;
	ip.* += 1;
	return true;
}

pub fn int(vm: *VM, core: *Core, ip: *align(1) u64) bool {
	//TODO
}

pub fn main() !void {
	const allocator = std.heap.page_allocator;
	const default_config = Config {
		.screen_width = 320,
		.screen_height = 180,
		.cores = 4,
		.mem_size = 0x100000,
		.mem = allocator
	};
	_ = VM.init(default_config);
}
//TODO distinction between signed and unsigned math
//TODO make offset jumps signed
