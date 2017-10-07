export q, @q

const q = _Q()

function (f::_Q)(cmd::String, args...)
    x = k(KDB_HANDLE[], cmd, map(K_new, args)...)
    systemerror("k", x == C_NULL)
    K(x)
end

macro q(ex::Expr)
    if ex.head === :let
        f = :(Dict())
        for s in ex.args[2:end]
            push!(f.args, :($(Meta.quot(s)) => $(esc(s))))
        end
        :(q("eval", resolve!($(esc(K(ex.args[1]))),$f)))
    else
        :(q("eval", $(esc(K(ex)))))
    end
end

macro q(x::Symbol)
    cmd = string(x)
    if cmd[1] == '_'
        cmd = "." * cmd[2:end]
    end
    :(q($cmd))
end

raw"""
 An idea for implementing the following syntax:

       @q let x, y
          x + til(y)
       end

The invocation above should treat x and y as Julia variables that
need to be sent to kdb+.

julia> macro frame(ex)
          f = :(Dict())
          for s in ex.args[2:end]
              push!(f.args, :($(Meta.quot(s)) => $(esc(s))))
          end
          f
       end
@frame (macro with 1 method)

julia> @macroexpand @frame(let x, y;end)
:((Main.Dict)(:x => x, :y => y))

The @q(let x,y;ex end) should expand into q("eval", resolve!(K(ex.args[1]), f))
expression, where f is the frame similar to the one generated by the @frame
macro above and resolve() is a function that substitutes the values from f to
a K parse tree.
"""
function resolve!(e, f)
    # TODO: Check e[1] and treat : differently.
    for (i, x) in enumerate(e)
        t = ktypecode(x)
        if t == KK
            resolve!(x, f)
        elseif t == -KS
            sym = Symbol(x)
            if haskey(f, sym)
                e[i] = K(f[sym])
            end
        end
    end
    e
end