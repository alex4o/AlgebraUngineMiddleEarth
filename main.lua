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
		int power;
		int maxTermPower;
		char letter;
		RootDescriptor rd;
		int minTerms;
		int maxTerms;
		bool nice;
	} EquationDescriptor;

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
		int maxPow; //Maximum power of expression

		int maxLetters; //Minimal and maximum number of letters in subterm
		int minLetters;

		int maxTerms;
		int minTerms;

		int minSubTerm, maxSubTerm;

		bool factored;

		CoefDescriptor cf;//Descriptor for the coef of letters, for example the 3 in 3a
		CoefDescriptor transformCF;
		
		char letters[8];
		int cLetters;

	} ExpressionDescriptor;

	Result oprosti(ExpressionDescriptor ed);

	MultiResult getEquations(EquationDescriptor ed, int count);
    MultiResult getExpressions(ExpressionDescriptor ed, int count);

	void free(void *ptr);
]]

-- connecting to the databes

pg.connect("host=127.0.0.1  user='postgres' password=illuminati dbname=math4all")
pg.bind("public")

-- defineing vars for jwt

local secret = "itanimulli"

local alg = "HS256"

-- loading /lib64/libalgebraEngine.so the generator library

local ae = ffi.load("AlgebraEngine")

-- alocate descriptors

ExpressionDescriptor = ffi.new("ExpressionDescriptor")
EquationDescriptor = ffi.new("EquationDescriptor")


ExpressionDescriptor.factored=false;


module("math", package.seeall, orbit.new)


function index(web)
	return render_index()
end

function post_qe(web)
	web:content_type("text/json")
	local data = cjson.decode(web.POST.post_data)
	--tprint(data)
	return QuadraticEquation(data.down, data.up, data.type[1], data.type[2])
end

function post_ee(web)
	web:content_type("text/json")
	local data = cjson.decode(web.POST.post_data)

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

	-- tprint(data)


	return EquivalentExpression(data.cor)
end

function post_get_equation(web)
	web:content_type("text/json")
	local data = cjson.decode(web.POST.post_data)
	-- tprint(data)

	EquationDescriptor.power = data.pow	
	EquationDescriptor.maxTermPower = data.powTerm
	EquationDescriptor.letter = string.byte(data.let:sub(1,1))
	EquationDescriptor.minTerms = data.Term.min
	EquationDescriptor.maxTerms = data.Term.max
	
	EquationDescriptor.rd.pNatural = data.root.type[1];
	EquationDescriptor.rd.pFraction = data.root.type[2];
	EquationDescriptor.rd.upHigh = data.root.up.high;
	EquationDescriptor.rd.upLow = data.root.up.low;
	EquationDescriptor.rd.downHigh = data.root.down.high; 
	EquationDescriptor.rd.downLow = data.root.down.low;

	return getEquation(data.cor)
end

function login(web)
	web:content_type("application/jwt")
	local data = cjson.decode(web.POST.post_data)
	--tprint(data)
	id = public.get_user(data.pass,data.name)["get_user"]
	if id == "" then
		payload = {
			user_id = -1
		}
	else
		payload = {
			user_id = id
		}
	end
	--print(type(id))

	local token = jwt.encode(payload, secret, alg)
	return token

end

function signup(web)
	web:content_type("application/jwt")
	local data = cjson.decode(web.POST.post_data)
	--tprint(data)
	res = public.create_user(data.username,data.password)

	--print(res)
end

-- routing the controllers  

math:dispatch_post(post_get_equation, "/gen/Equation/")
math:dispatch_get(index, "/", "/index.html")
math:dispatch_post(post_qe, "/gen/QuadraticEquation/")
math:dispatch_post(post_ee, "/gen/EquivalentExpression/")



math:dispatch_post(login,"/login/")
math:dispatch_post(signup,"/signup/")

function render_index()
	return html{
		head{ title "How did you get here?" },
		body{ p.hello"yhis is the api"}
	}
end

--[[
the following 3 functions call functions from Interface.cpp 
using the ffi definitions made on line 12.
]]
function EquivalentExpression(cor)
	results = {}
	res = ae.getExpressions(ExpressionDescriptor,cor)

	for i=0,res.count-1 do
		results[#results+1] = {
							problem = ffi.string(res.ptrProblem[i]),
							solution = ffi.string(res.ptrSolution[i])
							}

	end

	
	-- tprint(results)

	ffi.C.free(res.problem)
	ffi.C.free(res.solution)
	
	return cjson.encode(results);
end

function getEquation(cor)
	results = {}
	res = ae.getEquations(EquationDescriptor,cor)
	
	for i=0,res.count-1 do
		results[#results+1] = {
							problem = ffi.string(res.ptrProblem[i]),
							solution = ffi.string(res.ptrSolution[i])
							}

	end

	ffi.C.free(res.problem);
	ffi.C.free(res.solution);

	-- tprint(results)
	return cjson.encode(results)
end

function QuadraticEquation(down,up,F,N)
	local c_res = gen.generate(F,N,0,up.high,up.low,down.high,down.low,3)
	local math = {
		problem = ffi.string(c_res)
	}
	-- tprint(math)
	return cjson.encode(math)

end

orbit.htmlify(math, "render_.+")

return _M
