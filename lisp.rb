def tokenize(input)
  input
    .gsub('(', ' ( ')
    .gsub(')', ' ) ')
    .split(' ')
end

def parse(tokens, result = [])
  return if tokens.empty?

  token = tokens.shift
  if token == '(' # list
    list = []
    while tokens.first != ')'
      list << parse(tokens)
    end
    tokens.shift

    list
  else # not a list, so it's an atom
    atom(token)
  end
end

def atom(token)
  case token
  when /[0-9]+/ # number
    token.to_i
  else # a thing
    token.to_sym
  end
end

def reval(expr, env = $env)
  if expr.is_a?(Numeric)
    expr

  elsif expr.is_a?(Symbol)
    env[expr]

  elsif expr.nil?
    nil

  elsif expr[0] == :if # special form
    predicate = expr[1]
    truthy = expr[2]
    falsey = expr[3]

    if reval(predicate, env)
      reval(truthy, env)
    else
      reval(falsey, env)
    end

  elsif expr[0] == :def # special form
    name = expr[1]
    what = expr[2]
    env[name] = reval(what, env)

  elsif expr[0] == :let # special form
    pairs = expr[1]
    vars, vals = pairs.transpose
    actual_vals = vals.map { |val| reval(val, env) }

    stack = Hash[vars.zip(actual_vals)]
    body = expr[2..-1]

    retval = nil
    body.each do |body_expr|
      retval = reval(body_expr, env.merge(stack))
    end
    retval

  elsif expr[0] == :lambda # special form
    args_list = expr[1]
    body = expr[2..-1]

    eval(<<-EOS)
    lambda do |*args|
      stack = Hash[ args_list.zip(args) ]
      retval = nil
      body.each do |expr|
        retval = reval(expr, $env.merge(stack))
      end
      retval
    end
    EOS

  else # it's a function call
    # find the code for the func
    code = env[expr.first]
    # find the args
    args = expr.drop(1).map {|arg| reval(arg, env)}
    # apply
    code.call(*args)
  end
end

def read(input = gets)
  input = '' if input.nil? || input == "\n"
  parse(tokenize(input))
end

def repl
  loop do
    print '> '
    puts(reval(read, $env))
  end
end

$env = {
  :+ => lambda { |*args| args.reduce(:+) },
  :- => lambda { |*args| args.reduce(:-) },
  :< => lambda { |*args| args.first < args.last },
  :> => lambda { |*args| args.first > args.last },
  :'=' => lambda { |*args| args.first == args.last },
  :not => lambda { |*args| not args.first },
  :and => lambda { |*args| args.first && args.last },
  :or => lambda { |*args| args.first || args.last },
  :exit => lambda { |*args| abort },
}

DATA.read.split("\n\n").each do |form|
  reval(read(form))
end

begin
  repl
rescue Interrupt
  abort
end

__END__
(def <= (lambda (a b)
                (not (> a b))))

(def fib (lambda (n)
                 (if (<= n 2)
                   1
                   (+ (fib (- n 1)) (fib (- n 2))))))

(def foo (lambda (x)
                 (let ((y (+ x 10))
                       (z (fib 10)))
                      (+ y 10 z))))

(def bar (let ((x 10))
              (let ((x 30))
                   x)))
