load("fitness.jl",          dirname(@__FILE__))
load("fitness/simple.jl",   dirname(@__FILE__))
load("individual/stage.jl", dirname(@__FILE__))

# The base type used by all individuals.
abstract Individual

Base.isless(x::Individual, y::Individual) =
  !x.evaluated || (y.evaluated && x.fitness < y.fitness)
Base.isequal(x::Individual, y::Individual) = 
  !x.evaluated || (y.evaluated && x.fitness == y.fitness)

register("individual", Individual)
composer("individual") do s

  # Create an array to hold each of the lines of the type definition.
  # Add the evaluated and species properties.
  definition = ["evaluated::Bool"]#, "species::Species"]

  # Generate a property for each stage of development for this individual.
  # The genotype must be placed first; in order to do this, we generate a list
  # of stages, search for the genotype, and swap the stage at the first index
  # with the genotype stage.
  stages = collect(values(s["stages"]))
  for i in length(stages)
    if root(stages[i])
      t = stages[1]
      stages[1] = stages[i]
      stages[i] = t
    end
  end

  # With the stages in a safe order, proceed to generate a property
  # definition for each of them.
  for stage in stages
    push!(definition, "$(stage.label)::IndividualStage{$(chromosome(stage))}")
  end

  # Add the fitness property.
  push!(definition, "fitness::$(s["fitness"])")
  
  # Build the empty constructor.
  push!(definition, "constructor() = new(" * 
    join(vcat(["false"], ["IndividualStage{$(chromosome(stages[i]))}()" for i in 1:length(stages)]), ",") *  
    ")"
  )

  # Build the full constructor.
  push!(definition, "constructor(" *
    join([[], ["s$(i)::IndividualStage{$(chromosome(stages[i]))}" for i in 1:length(stages)]], ",") *
    ") = new(" *
    join(vcat(["false"], ["s$(i)" for i in 1:length(stages)]), ",") *
    ")"
  )

  # Add the header and footer to the type definition, before composing it
  # into an anonymous type.
  unshift!(definition, "type <: Individual")
  push!(definition, "end")
  t = anonymous_type(Wallace, join(definition, "\n"))

  # Build the cloning operation for this type.
  cloner = join([[], ["i.$(stage.label)" for stage in stages]], ",")
  cloner = "clone(i::$(t)) = $(t)($(cloner))"
  eval(Wallace, parse(cloner))

  # Build the describe operation for this type.
  describer = join(vcat(["fitness: \$(describe(i.fitness))"], ["$(stage.label):\n\$(describe(i.$(stage.label)))" for stage in stages]), "\n")
  describer = "describe(i::$(t)) = \"$(describer)\""
  eval(Wallace, parse(describer))
  
  # Return the generated individual type.
  return t

end
