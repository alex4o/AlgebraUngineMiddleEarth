-- loading libraries

local ffi = require("ffi")

local orbit = require("orbit")
local cjson = require("cjson")
local jwt = require("luajwt")
local base64 = require("base64")
local pg = require('pgproc')

-- defineing the C functions that will be used

ffi.cdef[[
	const char* generate(int Fraction,int Natural,int Irational,int uh,int ul,int dh,int dl,int count);

	typedef struct
	{
		char* problem;
		char* solution;
	} Result;

	typedef struct
	{
		char* problem;
		char* solution;
		char* ptrProblem[30];
		char* ptrSolution[30];
		int count;
	} MultiResult;

	typedef struct
	{
		int pNatural, pFraction, pIrational;
		int upLow, upHigh, downLow, downHigh;
		int pNegative;
	} RootDescriptor;

	typedef struct
	{
		int pNatural;
		int pRational;
		int pIrational;

		int pNegative;

		int upLow, upHigh, downLow, downHigh;
	} CoefDescriptor;

	typedef struct
	{
		int power;
		int maxTermPower;
		int minTerms;
		int maxTerms;
		char letter;
		char type;
		RootDescriptor rd;
		CoefDescriptor cd;
		CoefDescriptor transformCF;
		bool nice;
	} EquationDescriptor;

	typedef struct
	{
		int maxPow; //Maximum power of expression

		int maxLetters; //Minimal and maximum number of letters in subterm
		int minLetters;

		int maxTerms;
		int minTerms;

		int minSubTerm, maxSubTerm;

		bool factored;

		CoefDescriptor cf; //Descriptor for the coef of letters, for example the 3 in 3a
		CoefDescriptor transformCF;

		char letters[8];
		int cLetters;

	} ExpressionDescriptor;

	typedef struct
	{
		CoefDescriptor cf;
		CoefDescriptor tcf;
		RootDescriptor rd;
		char letter;
		bool nice;
		int minTerms, maxTerms, maxTermPower;
	} InequationDescriptor;

	Result oprosti(ExpressionDescriptor ed);

	MultiResult getEquations(EquationDescriptor ed, int count);
	MultiResult getExpressions(ExpressionDescriptor ed, int count);
	MultiResult getInequations(InequationDescriptor id, int count);

	void free(void *ptr);
]]

-- connecting to the databes
tprint = function(t, exclusions)
	local nests = 0
	if not exclusions then exclusions = {} end
	local recurse = function(t, recurse, exclusions)
		indent = function()
			for i = 1, nests do
				io.write("    ")
			end
		end
		local excluded = function(key)
			for k,v in pairs(exclusions) do
				if v == key then
					return true
				end
			end
			return false
		end
		local isFirst = true
		for k,v in pairs(t) do
			if isFirst then
				indent()
				print("|")
				isFirst = false
			end
			if type(v) == "table" and not excluded(k) then
				indent()
				print("|-> "..k..": "..type(v))
				nests = nests + 1
				recurse(v, recurse, exclusions)
			elseif excluded(k) then
				indent()
				print("|-> "..k..": "..type(v))
			elseif type(v) == "userdata" or type(v) == "function" then
				indent()
				print("|-> "..k..": "..type(v))
			elseif type(v) == "string" then
				indent()
				print("|-> "..k..": ".."\""..v.."\"")
			else
				indent()
				print("|-> "..k..": "..v)
			end
		end
		nests = nests - 1
	end

	nests = 0
	print("### START TABLE ###")
	for k,v in pairs(t) do
		print("root")
		if type(v) == "table" then
			print("|-> "..k..": "..type(v))
			nests = nests + 1
			recurse(v, recurse, exclusions)
		elseif type(v) == "userdata" or type(v) == "function" then
			print("|-> "..k..": "..type(v))
		elseif type(v) == "string" then
			print("|-> "..k..": ".."\""..v.."\"")
		else
			print("|-> "..k..": "..v)
		end
	end
	print("### END TABLE ###")
end

pg.connect("host=127.0.0.1  user='postgres' password=qwerty dbname=math4all")

pg.bind("public")

-- defineing vars for jwt

local secret = "itanimulli"

local alg = "HS256"

-- loading /lib64/libalgebraEngine.so the generator library

local ae = ffi.load("AlgebraEngine")

-- alocate descriptors

ExpressionDescriptor = ffi.new("ExpressionDescriptor")
EquationDescriptor = ffi.new("EquationDescriptor")
InequationDescriptor = ffi.new("InequationDescriptor")




module("math", package.seeall, orbit.new)


function index(web)
	return render_index()
end

function post_ee(web)
	web:content_type("text/json")
	local data = cjson.decode(web.POST.post_data)

	ExpressionDescriptor.factored=data.factored;
	ExpressionDescriptor.maxPow = data.pow;
	ExpressionDescriptor.minTerms=data.Term.min;
	ExpressionDescriptor.maxTerms=data.Term.max;

	ExpressionDescriptor.minSubTerm=1;
	ExpressionDescriptor.maxSubTerm=data.pow

	ExpressionDescriptor.minLetters=data.Letters.min;
	ExpressionDescriptor.maxLetters=data.Letters.max;

	ffi.copy(ExpressionDescriptor.letters,data.let)
	ExpressionDescriptor.cLetters = #data.let


	ExpressionDescriptor.cf.pNatural = data.coef.type[1];
	ExpressionDescriptor.cf.pRational = data.coef.type[2];
	ExpressionDescriptor.cf.upHigh = data.coef.up.high;
	ExpressionDescriptor.cf.upLow = data.coef.up.low;
	ExpressionDescriptor.cf.downHigh = data.coef.down.high;
	ExpressionDescriptor.cf.downLow = data.coef.down.low;

	ExpressionDescriptor.transformCF.pNatural = data.tcoef.type[1];
	ExpressionDescriptor.transformCF.pRational = data.tcoef.type[2];
	ExpressionDescriptor.transformCF.upHigh = data.tcoef.up.high;
	ExpressionDescriptor.transformCF.upLow = data.tcoef.up.low;
	ExpressionDescriptor.transformCF.downHigh = data.tcoef.down.high;
	ExpressionDescriptor.transformCF.downLow = data.tcoef.down.low;


	ExpressionDescriptor.cf.pIrational = 0;
	ExpressionDescriptor.transformCF.pIrational = 0;

	--tprint(data)


	return Generate(ae.getExpressions,ExpressionDescriptor,data)
end

function post_get_equation(web)
	web:content_type("text/json")


	local data = cjson.decode(web.POST.post_data)

	tprint(data)
	EquationDescriptor.nice=true;

	EquationDescriptor.power = data.pow
	EquationDescriptor.maxTermPower = data.powTerm
	EquationDescriptor.letter = string.byte(data.let:sub(1,1))
	EquationDescriptor.minTerms = data.Term.min
	EquationDescriptor.maxTerms = data.Term.max

-- 0 нормално
-- 1 няма решение
-- 2 всяко x

	EquationDescriptor.type = data.type;

	EquationDescriptor.rd.pNatural = data.root.type[1];
	EquationDescriptor.rd.pFraction = data.root.type[2];
	EquationDescriptor.rd.upHigh = data.root.up.high;
	EquationDescriptor.rd.upLow = data.root.up.low;
	EquationDescriptor.rd.downHigh = data.root.down.high;
	EquationDescriptor.rd.downLow = data.root.down.low;

	EquationDescriptor.cd.pNatural = data.coef.type[1];
	EquationDescriptor.cd.pRational = data.coef.type[2];
	EquationDescriptor.cd.upHigh = data.coef.up.high;
	EquationDescriptor.cd.upLow = data.coef.up.low;
	EquationDescriptor.cd.downHigh = data.coef.down.high;
	EquationDescriptor.cd.downLow = data.coef.down.low;

	EquationDescriptor.transformCF.pNatural = data.tcoef.type[1];
	EquationDescriptor.transformCF.pRational = data.tcoef.type[2];
	EquationDescriptor.transformCF.upHigh = data.tcoef.up.high;
	EquationDescriptor.transformCF.upLow = data.tcoef.up.low;
	EquationDescriptor.transformCF.downHigh = data.tcoef.down.high;
	EquationDescriptor.transformCF.downLow = data.tcoef.down.low;



	return Generate(ae.getEquations,EquationDescriptor,data)
end

function getInequation(web)
	web:content_type("text/json")
	local data = cjson.decode(web.POST.post_data)

	InequationDescriptor.nice=true;


	InequationDescriptor.maxTermPower = data.powTerm
	InequationDescriptor.letter = string.byte(data.let:sub(1,1))
	InequationDescriptor.minTerms = data.Term.min
	InequationDescriptor.maxTerms = data.Term.max

	InequationDescriptor.cf.pNatural = data.coef.type[1];
	InequationDescriptor.cf.pRational = data.coef.type[2];
	InequationDescriptor.cf.upHigh = data.coef.up.high;
	InequationDescriptor.cf.upLow = data.coef.up.low;
	InequationDescriptor.cf.downHigh = data.coef.down.high;
	InequationDescriptor.cf.downLow = data.coef.down.low;

	InequationDescriptor.tcf.pNatural = data.tcoef.type[1];
	InequationDescriptor.tcf.pRational = data.tcoef.type[2];
	InequationDescriptor.tcf.upHigh = data.tcoef.up.high;
	InequationDescriptor.tcf.upLow = data.tcoef.up.low;
	InequationDescriptor.tcf.downHigh = data.tcoef.down.high;
	InequationDescriptor.tcf.downLow = data.tcoef.down.low;

	InequationDescriptor.rd.pNatural = data.root.type[1];
	InequationDescriptor.rd.pFraction = data.root.type[2];
	InequationDescriptor.rd.upHigh = data.root.up.high;
	InequationDescriptor.rd.upLow = data.root.up.low;
	InequationDescriptor.rd.downHigh = data.root.down.high;
	InequationDescriptor.rd.downLow = data.root.down.low;



	return Generate(ae.getInequations,InequationDescriptor,data)

end


-- getting settings list
function getSettings(web)
	local id = getUserId(web.GET.token)
	tprint(public.get_settings(id));
	return cjson.encode(public.get_settings(id));
end

-- get specific setting for user
function getSetting(web)
	local id = getUserId(web.GET.token)

end

-- createing and seving settings
function postSettings(web)
	local id = getUserId(web.GET.token)

end

function getProblems(web)
	web:content_type("text/json")

	return cjson.encode(public.get_problems(getUserId(web.GET.token)))
end

function getUserId(token)
	local err,data = checkToken(token)

	if err then
		return 0

	else
		return data.user_id
	end
end

function checkToken(token)
	if token == nil then
		return true
	end
	local data, err = jwt.decode(token, secret, true)
	if err~=nil or data==nil then
		print(err)
		return true
	else
		return false, data
	end
end

function login(web)
	web:content_type("application/jwt")
	local data = cjson.decode(web.POST.post_data)
	--tprint(data)
	dbres = public.get_user(data.name, data.pass)
	tprint(dbres)
	print(dbres)
	if dbres[1] == nil then
		payload = {
			user_id = -1
		}
	else
		id = dbres[1]["user_id"]
		uname = dbres[1]["name"]


		payload = {
			user_id = id,
			user = uname,
			nbf = os.time(),
			exp = os.time() + 3600
		}
	end
	--print(type(id))

	local token = jwt.encode(payload, secret, alg)
	return token

end

function signup(web)
	web:content_type("application/json")
	local data = cjson.decode(web.POST.post_data)
	tprint(data)
	res = public.new_user(data.name,data.pass)
	tprint(res)
	if res[1]["new_user"] == "1" then
		return cjson.encode({ok = true})
	else
		return cjson.encode({ok = false})
	end
	--print(res)
end

-- routing the controllers

math:dispatch_post(post_get_equation, "/gen/Equation/")
math:dispatch_get(index, "/", "/index.html")
math:dispatch_post(post_qe, "/gen/QuadraticEquation/")
math:dispatch_post(post_ee, "/gen/EquivalentExpression/")
math:dispatch_post(getInequation, "/gen/Inequation/")

math:dispatch_get(getSettings, "/data/settings/")

math:dispatch_get(getProblems, "/data/problems/")

math:dispatch_post(login,"/login/")
math:dispatch_post(signup,"/signup/")

function render_index()
	return html{
		head{ title "How did you get here?" },
		body{ p.hello "this is the api"}
	}
end

--[[
this function accecpt function argument
using the ffi definitions made on line 12.
]]

function Generate(func,descriptor,data)
	results = {}
	local err,tdata = checkToken(data.token)
	if err then
		id = 0
	else
		id = tdata.user_id
	end

	local res = func(descriptor,data.cor)

	for i=0,res.count-1 do
		local p = ffi.string(res.ptrProblem[i])
		local s = ffi.string(res.ptrSolution[i])

		results[#results+1] = {
							problem = p,
							solution = s
							}

		public.new_problem(id,p,s)

	end
	ffi.C.free(res.problem)
	ffi.C.free(res.solution)

	return cjson.encode(results)
end

orbit.htmlify(math, "render_.+")

return _M
