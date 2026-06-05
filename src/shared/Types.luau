export type ClientInfo = {
	KeysPressed: { Enum.KeyCode? },
	MouseLocation: Vector2,
}

export type StateMachine = {
	CurrentState: State?,
	LastState: State?,
	Queue: { State },
	Transition: (State) -> (),
	Clear: () -> (),
	Update: (number) -> (),
}

export type State = {
	OnEnter: () -> (),
	OnExit: () -> (),
	Update: (number) -> (),
	Priority: number,
	Name: string,
	Elapsed: number,
	Duration: number?,
	At: number,
	StateMachine: StateMachine?,
}

return {}
