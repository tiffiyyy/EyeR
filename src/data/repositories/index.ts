import { MemoriesRepository } from "@/src/data/repositories/memoriesRepository";
import { PeopleRepository } from "@/src/data/repositories/peopleRepository";

export const peopleRepository = new PeopleRepository();
export const memoriesRepository = new MemoriesRepository();
