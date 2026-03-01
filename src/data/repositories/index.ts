import { InteractionsRepository } from "@/src/data/repositories/interactionsRepository";
import { PeopleRepository } from "@/src/data/repositories/peopleRepository";
import { RoomsRepository } from "@/src/data/repositories/roomsRepository";

export const peopleRepository = new PeopleRepository();
export const interactionsRepository = new InteractionsRepository();
export const roomsRepository = new RoomsRepository();
