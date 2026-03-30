defmodule Lobber.Tasks.Scheduler do
  use Quantum, otp_app: :lobber, storage: Lobber.Tasks.CaveStorage
end
