using NeuralPDE
using Quadrature, Cubature, Cuba
using Flux, ModelingToolkit, GalacticOptim, Optim, DiffEqFlux
using Plots
using PyPlot
using DelimitedFiles
using QuasiMonteCarlo

print("Precompiling Done")

#level_set(NeuralPDE.QuadratureTraining(algorithm = CubaCuhre(), reltol = 1e-8, abstol = 1e-8, maxiters = 100), GalacticOptim.ADAM(0.01), 30)

function level_set(strategy, minimizer, maxIters)

    ##  DECLARATIONS
    @parameters  t x y
    @variables   u(..)
    @derivatives Dt'~t
    @derivatives Dx'~x
    @derivatives Dy'~y

    # Discretization
    xwidth      = 1.0      #ft
    ywidth      = 1.0
    tmax        = 1.0      #min
    xScale      = 1.0
    yScale      = 1.0
    xMeshNum    = 10
    yMeshNum    = 10
    tMeshNum    = 10
    dx  = xwidth/xMeshNum
    dy  = ywidth/yMeshNum
    dt  = tmax/tMeshNum


    domains = [t ∈ IntervalDomain(0.0,tmax),
               x ∈ IntervalDomain(0.0,xwidth),
               y ∈ IntervalDomain(0.0,ywidth)]

    xs = 0.0 : dx : xwidth
    ys = 0.0 : dy : ywidth
    ts = 0.0 : dt : tmax

    ### EQUATION

    # Write your own

    ## NEURAL NETWORK
    n = 16   #neuron number

    chain = FastChain(FastDense(3,n,Flux.σ),FastDense(n,n,Flux.σ),FastDense(n,1))   #Neural network from Flux library

    discretization = NeuralPDE.PhysicsInformedNN(chain, strategy = strategy)

    indvars = [t,x,y]   #phisically independent variables
    depvars = [u]       #dependent (target) variable

    dim = length(domains)

    losses = []
    cb = function (p,l)     #loss function handling
        println("Current loss is: $l")
        append!(losses, l)
        return false
    end

    pde_system = PDESystem(eq, bcs, domains, indvars, depvars)
    prob = discretize(pde_system, discretization)

    t_0 = time_ns()
    res = GalacticOptim.solve(prob, minimizer; cb = cb, maxiters=maxIters) #allow_f_increase = false,
    t_f = time_ns()
    print(string("Training time = ",(t_f - t_0)/10^9))

    phi = discretization.phi

    printBCSComp = true     #prints initial condition comparison and training loss plot

    domain = [ts, xs, ys]

    u_predict = [reshape([first(phi([t,x,y],res.minimizer)) for t in ts for x in xs for y in ys], (length(ts),length(xs),length(ys)))]  #matrix of model's prediction

    #maxlim = maximum(maximum(u_predict[t]) for t = 1:length(ts))
    #minlim = minimum(minimum(u_predict[t]) for t = 1:length(ts))

    #    trainingPlot = Plots.plot(1:(maxIters + 1), losses, yaxis=:log, title = string("Training time = 270 s",
    #        "\\n Iterations: ", maxIters, "   NN: 3>16>1"), ylabel = "log(loss)", legend = false) #loss plot

    return [losses, u_predict, u_predict,  domain, training_time] #add numeric solution
end
